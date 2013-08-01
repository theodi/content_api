require 'sinatra'
require 'sinatra/cross_origin'
require 'rabl'
require 'mongoid'
require 'govspeak'
require 'plek'
require 'url_helpers'
require 'content_format_helpers'
require 'timestamp_helpers'
require 'gds_api/helpers'
require 'gds_api/rummager'
require_relative "config"
require 'statsd'
require 'config/gds_sso_middleware'
require 'pagination'
require 'tag_types'
require 'ostruct'

require "url_helper"
require "presenters/result_set_presenter"
require "presenters/search_result_presenter"
require "presenters/tag_presenter"
require "presenters/basic_artefact_presenter"

# Note: the artefact patch needs to be included before the Kaminari patch,
# otherwise it doesn't work. I haven't quite got to the bottom of why that is.
require 'artefact'
require 'section_extensions'

require 'config/kaminari'
require 'config/rabl'

class GovUkContentApi < Sinatra::Application
  helpers URLHelpers, GdsApi::Helpers, ContentFormatHelpers, TimestampHelpers
  
  configure do
    enable :cross_origin
  end

  include Pagination

  DEFAULT_CACHE_TIME = 15.minutes.to_i
  LONG_CACHE_TIME = 1.hour.to_i

  ERROR_CODES = {
    401 => "unauthorised",
    403 => "forbidden",
    404 => "not found",
    410 => "gone",
    422 => "unprocessable",
    503 => "unavailable"
  }

  set :views, File.expand_path('views', File.dirname(__FILE__))
  set :show_exceptions, false

  def url_helper
    parameters = [self, Plek.current.website_root, env['HTTP_API_PREFIX']]

    # When running in development mode we may want the URL for the item
    # as served directly by the app that provides it. We can trigger this by
    # providing the current Plek instance to the URL helper.
    unless ["production", "test"].include?(ENV["RACK_ENV"])
      parameters << Plek.current
    end

    URLHelper.new(*parameters)
  end

  def known_tag_types
    @known_tag_types ||= TagTypes.new(Artefact.tag_types - ["roles"])
  end

  error Mongo::MongoDBError, Mongo::MongoRubyError do
    statsd.increment("mongo_error")
    raise
  end

  before do
    content_type :json
    @role = params[:role] || ENV['CONTENTAPI_DEFAULT_ROLE']
  end

  get "/search.json" do
    begin
      @statsd_scope = "request.search"
      search_index = params[:index] || 'mainstream'

      unless ['mainstream', 'detailed', 'government'].include?(search_index)
        custom_404
      end

      if params[:q].nil? || params[:q].strip.empty?
        custom_error(422, "Non-empty querystring is required in the 'q' parameter")
      end

      statsd.time(@statsd_scope) do
        search_uri = Plek.current.find('search') + "/#{search_index}"
        client = GdsApi::Rummager.new(search_uri)
        @results = client.search(params[:q])["results"]
      end

      result_set = FakePaginatedResultSet.new(@results)
      present_result = lambda do |result|
        SearchResultPresenter.new(result, url_helper)
      end
      presenter = ResultSetPresenter.new(result_set, present_result)

      presenter.present.to_json
    rescue GdsApi::HTTPErrorResponse, GdsApi::TimedOutException
      custom_503
    end
  end

  get "/tags.json" do
    expires DEFAULT_CACHE_TIME

    @statsd_scope = "request.tags"
    options = {}
    if params[:type]
      options["tag_type"] = params[:type]
    end
    if params[:parent_id]
      options["parent_id"] = params[:parent_id]
    end
    if params[:root_sections]
      options["parent_id"] = nil
    end

    allowed_params = params.slice *%w(type parent_id root_sections)

    tags = if options.length > 0
      statsd.time(@statsd_scope) do
        Tag.where(options)
      end
    else
      statsd.time("#{@statsd_scope}.all") do
        Tag
      end
    end

    if settings.pagination
      begin
        paginated_tags = paginated(tags, params[:page])
      rescue InvalidPage
        # TODO: is it worth recording at a more granular level what's wrong?
        statsd.increment('request.tags.bad_page')
        custom_404
      end

      @result_set = PaginatedResultSet.new(paginated_tags)
      @result_set.populate_page_links { |page_number|
        tags_url(allowed_params, page_number)
      }

      headers "Link" => LinkHeader.new(@result_set.links).to_s
    else
      # If the scope is Tag, we need to use Tag.all instead, because the class
      # itself is not a Mongo Criteria object
      tags_scope = tags.is_a?(Class) ? tags.all : tags
      @result_set = FakePaginatedResultSet.new(tags_scope)
    end

    present_result = lambda do |result|
      TagPresenter.new(result, url_helper)
    end
    presenter = ResultSetPresenter.new(
      @result_set,
      present_result,
      # This is replicating the existing behaviour from the RABL implementation
      # TODO: make this actually describe the results
      description: "All tags"
    )
    presenter.present.to_json
  end

  get "/tag_types.json" do
    expires LONG_CACHE_TIME

    tag_types = known_tag_types.map { |tag_type|
      OpenStruct.new(
        id: tag_type_url(tag_type),
        type: tag_type.singular,
        total: Tag.where(tag_type: tag_type.singular).count
      )
    }
    @result_set = FakePaginatedResultSet.new(tag_types)
    render :rabl, :tag_types, format: "json"
  end

  get "/tags/:tag_type_or_id.json" do
    expires DEFAULT_CACHE_TIME

    @statsd_scope = "request.tag"

    tag_type = known_tag_types.from_plural(params[:tag_type_or_id])

    # We respond with a 404 to unknown tag types, because the resource of "all
    # tags of type <x>" does not exist when we don't recognise x
    unless tag_type

      # Redirect from a singular tag type to its plural
      # e.g. /tags/section.json => /tags/sections.json
      tag_type = known_tag_types.from_singular(params[:tag_type_or_id])
      redirect(tag_type_url(tag_type)) if tag_type

      # Tags used to be accessed through /tags/tag_id.json, so we check here
      # whether one exists to avoid breaking the Web. We only check for section
      # tags, as at the time of change sections were the only tag type in use
      # in production
      section = Tag.by_tag_id(params[:tag_type_or_id], "section")
      redirect(tag_url(section)) if section

      custom_404
    end

    @tag_type_name = tag_type.singular
    tags = Tag.where(tag_type: @tag_type_name)

    if @tag_type_name == "section"
      # Extra functionality for sections: roots and parents
      if params[:parent_id] && params[:root_sections]
        custom_404  # Doesn't make sense to have both of these parameters
      end
      if params[:parent_id]
        # Look up parent tag and add to criteria
        if Tag.by_tag_id(params[:parent_id], "section")
          tags = tags.where(parent_id: params[:parent_id])
        else
          custom_404
        end
      end
      if params[:root_sections]
        tags = tags.where(parent_id: nil)
      end
    end

    @result_set = FakePaginatedResultSet.new(tags)

    present_result = lambda do |result|
      TagPresenter.new(result, url_helper)
    end
    presenter = ResultSetPresenter.new(
      @result_set,
      present_result,
      # This description replicates the existing behaviour from RABL
      # TODO: make the description describe the results in all cases
      description: "All '#{@tag_type_name}' tags"
    )
    presenter.present.to_json
  end

  get "/tags/:tag_type/:tag_id.json" do
    expires DEFAULT_CACHE_TIME

    tag_type = known_tag_types.from_plural(params[:tag_type])
    custom_404 unless tag_type

    @tag = Tag.by_tag_id(params[:tag_id], tag_type.singular)
    if @tag
      tag_presenter = TagPresenter.new(@tag, url_helper)
      SingleResultPresenter.new(tag_presenter).present.to_json
    else
      custom_404
    end
  end

  # Show the artefacts with a given tag
  #
  # Examples:
  #
  #   /with_tag.json?section=crime
  #    - all artefacts in the Crime section
  #   /with_tag.json?section=crime&sort=curated
  #    - all artefacts in the Crime section, with any curated ones first
  get "/with_tag.json" do
    expires DEFAULT_CACHE_TIME

    @statsd_scope = 'request.with_tag'

    unless params[:tag].blank?
      # Old-style tag URLs without types specified

      # If comma-separated tags given, we've stopped supporting that for now
      if params[:tag].include? ","
        custom_404
      end

      possible_tags = Tag.where(tag_id: params[:tag]).to_a
      content_types = Artefact::FORMATS_BY_DEFAULT_OWNING_APP["publisher"]
      modifier_params = params.slice('sort', 'author', 'node', 'organization_name', 'role', 'whole_body')
      # If we can unambiguously determine the tag, redirect to its correct URL
      if possible_tags.count == 1
        redirect with_tag_url(possible_tags, modifier_params)
      # If the tag is a content type, redirect to the type's URL
      elsif content_types.include? params[:tag].singularize
        redirect with_type_url(params[:tag], modifier_params)
      else
        custom_404
      end
    end
    
    if params[:type].blank?    
      requested_tags = known_tag_types.each_with_object([]) do |tag_type, req|
        unless params[tag_type.singular].blank?
          req << Tag.by_tag_id(params[tag_type.singular], tag_type.singular)
        end
      end

      # If any of the tags weren't found, that's enough to 404
      custom_404 if requested_tags.any? &:nil?

      # For now, we only support retrieving by a single tag
      custom_404 unless requested_tags.size == 1
      
      if params[:sort]
        custom_404 unless ["curated", "alphabetical", "date"].include?(params[:sort])
      end

      tag_id = requested_tags.first.tag_id
      tag_type = requested_tags.first.tag_type
      @description = "All content with the '#{tag_id}' #{tag_type}"

      artefacts = sorted_artefacts_for_tag_id(
        tag_id,
        params[:sort],
        params.slice('author', 'node', 'organization_name')
      )
    else
      # Singularize type here, so we can request for types like "/jobs", rather than "/job" in frontend app
      type = params[:type].singularize
      @description = "All content with the #{type} type"
      artefacts = Artefact.where(:kind => type, :tag_ids => @role)
      
      if params[:sort] == "date"
        artefacts.order_by(:created_at.desc)
      end
      
      # If there are no artefacts for this content type, return 404
      custom_404 if artefacts.count == 0
    end
    
    results = map_artefacts_and_add_editions(artefacts)
    @result_set = FakePaginatedResultSet.new(results)

    render :rabl, :with_tag, format: "json"
  end
  
  # Get the newest artefact by tag or type
  get "/latest.json" do
    if params[:type]
      # Check the type exists
      content_types = Artefact::FORMATS_BY_DEFAULT_OWNING_APP["publisher"]
      custom_404 unless content_types.include? params[:type].singularize 
      
      artefact = Artefact.live.where(kind: params[:type]).order_by(:created_at.desc).first
    elsif params[:tag]
      # Check the tag exists
      possible_tags = Tag.where(tag_id: params[:tag]).to_a
      custom_404 if possible_tags.count == 0
      
      artefact = Artefact.live.where(tag_ids: params[:tag]).order_by(:created_at.desc).first
    end
    get_artefact(artefact.slug, params)
  end
  
  # Get the next upcoming artefact (such as an event or course_instance) by type
  get "/upcoming.json" do
    if params[:order_by] && params[:type]
      type = "#{params[:type].camelize}Edition"
      
      # Check the type exists
      custom_404 unless Object.const_defined?(type)
      
      # Check the field we want to query exists
      custom_404 unless type.constantize.fields.keys.include? params[:order_by]
      
      edition = type.constantize.where(:state => "published", params[:order_by].to_sym => {:$gte => Date.today.to_time.utc}).order_by(params[:order_by].to_sym.asc).first
      get_artefact(edition.slug, params)
    end
  end
  
  get "/course-instance.json" do    
    if params[:course] && params[:date]          
      instance = CourseInstanceEdition.where(:course => params[:course], :date => {:$gte => Date.parse(params[:date]), :$lt => (Date.parse(params[:date]) + 1.day) })
      
      custom_404 if instance.count == 0
      
      get_artefact(instance.first.slug, { edition: params[:edition] })
    else
      custom_404
    end
  end
  
  get "/section.json" do
    if params[:id]
      @section = Section.where(:tag_id => params[:id]).first
      attach_non_artefact_asset(@section, :hero_image)
      
      custom_404 if @section.nil?
      
      @section.modules.map! do |m| 
        section_module = SectionModule.find(m) 
        attach_non_artefact_asset(section_module, :image)
        section_module
      end
      
      render :rabl, :section, format: "json"
    end
  end
  
  get "/related.json" do
    kv = params.first
    type = kv[0]
    item = kv[1]
    
    allowed_types = ['course']
    
    unless allowed_types.include?(type)
      custom_404
    else    
      editions = Edition.where(type => item, :state => 'published')
    
      custom_404 if editions.count == 0
    
      @description = "All items with #{type} #{item}"
    
      @results = map_editions_with_artefacts(editions)
      @result_set = FakePaginatedResultSet.new(@results)
    
      render :rabl, :with_tag, format: "json"
    end
  end

  get "/artefacts.json" do
    expires DEFAULT_CACHE_TIME

    artefacts = statsd.time("request.artefacts") do
      a = Artefact.live.where(:tag_ids => @role)
      sliced_params = params.slice('author', 'node', 'organization_name')
      if !sliced_params.empty?
        a = a.where(sliced_params)
      end
      a
    end

    if settings.pagination
      begin
        paginated_artefacts = paginated(artefacts, params[:page])
      rescue InvalidPage
        statsd.increment('request.tags.bad_page')
        custom_404
      end

      @result_set = PaginatedResultSet.new(paginated_artefacts)
      @result_set.populate_page_links { |page_number| artefacts_url(page_number) }
      headers "Link" => LinkHeader.new(@result_set.links).to_s
    else
      @result_set = FakePaginatedResultSet.new(artefacts)
    end

    present_result = lambda do |result|
      BasicArtefactPresenter.new(result, url_helper)
    end
    presenter = ResultSetPresenter.new(
      @result_set,
      present_result
    )
    presenter.present.to_json
  end

  get "/*.json" do |id|
    get_artefact(id, params)
  end

  protected
  
  def get_artefact(id, params)
    # The edition param is for accessing unpublished editions in order for
    # editors to preview them. These can change frequently and so shouldn't be
    # cached.
    expire_after = params[:edition] ? 0 : DEFAULT_CACHE_TIME
    expires(expire_after)

    @statsd_scope = "request.artefact"
    verify_unpublished_permission if params[:edition]

    statsd.time(@statsd_scope) do
      @artefact = Artefact.find_by_slug_and_tag_ids(id, @role)
    end

    custom_404 unless @artefact
    handle_unpublished_artefact(@artefact) unless params[:edition]
    
    @author = @artefact.author_edition
    @nodes = @artefact.node_editions
    @organizations = @artefact.organization_editions

    if @artefact.owning_app == 'publisher'
      attach_publisher_edition(@artefact, params[:edition])
    end

    render :rabl, :artefact, format: "json"
  end

  def map_editions_with_artefacts(editions)
    statsd.time("#{@statsd_scope}.map_editions_to_artefacts") do
      artefact_ids = editions.collect(&:panopticon_id)
      matching_artefacts = Artefact.live.any_in(_id: artefact_ids)

      matching_artefacts.map do |artefact|
        artefact.edition = editions.detect { |e| e.panopticon_id.to_s == artefact.id.to_s }
        artefact
      end
    end
  end

  def map_artefacts_and_add_editions(artefacts)
    statsd.time("#{@statsd_scope}.map_results") do
      # Preload to avoid hundreds of individual queries
      editions_by_slug = published_editions_for_artefacts(artefacts)

      results = artefacts.map do |artefact|
        if artefact.owning_app == 'publisher'
          a = artefact_with_edition(artefact, editions_by_slug)
        else
          a = artefact
        end
        unless a.nil?
          attach_assets(a, :image) if a.edition.is_a?(PersonEdition)
          attach_assets(a, :file) if a.edition.is_a?(CreativeWorkEdition)
          attach_assets(a, :logo) if a.edition.is_a?(NodeEdition)
          attach_assets(a, :report) if a.edition.is_a?(ReportEdition)
        end
        a
      end

      results.compact
    end
  end

  def sorted_artefacts_for_tag_id(tag_id, sort, filter = {})
    statsd.time("#{@statsd_scope}.#{tag_id}") do    
      artefacts = Artefact.live.where(filter).all(tag_ids: [tag_id, @role])
      
      if sort == "date"
        artefacts = artefacts.order_by(:created_at.desc)
      else
        # Load in the curated list and use it as an ordering for the top items in
        # the list. Any artefacts not present in the list go on the end, in
        # alphabetical name order.
        #
        # For example, if the curated list is
        #
        #     [3, 1, 2]
        #
        # and the items have ids
        #
        #     [1, 2, 3, 4, 5]
        #
        # the sorted list will be one of the following:
        #
        #     [3, 1, 2, 4, 5]
        #     [3, 1, 2, 5, 4]
        #
        # depending on the names of artefacts 4 and 5.
        #
        # If the sort order is alphabetical rather than curated, this is
        # equivalent to the special case of curated ordering where the curated
        # list is empty

        if sort == "curated"
          curated_list = CuratedList.where(tag_ids: [tag_id]).first
          first_ids = curated_list ? curated_list.artefact_ids : []        
        else
          # Just fall back on alphabetical order
          first_ids = []
        end

        return artefacts.to_a.sort_by { |artefact|
          [
            first_ids.find_index(artefact._id) || first_ids.length,
            artefact.name
          ]
        }
      end
    end
  end

  def published_editions_for_artefacts(artefacts)
    return [] if artefacts.empty?

    slugs = artefacts.map(&:slug)
    published_editions_for_artefacts = Edition.published.any_in(slug: slugs)
    published_editions_for_artefacts.each_with_object({}) do |edition, result_hash|
      result_hash[edition.slug] = edition
    end
  end

  def artefact_with_edition(artefact, editions_by_slug)
    artefact.edition = editions_by_slug[artefact.slug]
    if artefact.edition
      artefact
    else
      nil
    end
  end

  def handle_unpublished_artefact(artefact)
    if artefact.state == 'archived'
      custom_410
    elsif artefact.state != 'live'
      custom_404
    end
  end

  def attach_publisher_edition(artefact, version_number = nil)    
    statsd.time("#{@statsd_scope}.edition") do
      artefact.edition = if version_number
        Edition.where(panopticon_id: artefact.id, version_number: version_number).first
      else
        Edition.where(panopticon_id: artefact.id, state: 'published').last ||
          Edition.where(panopticon_id: artefact.id).first
      end
    end

    if version_number && artefact.edition.nil?
      custom_404
    end
    if artefact.edition && version_number.nil?
      if artefact.edition.state == 'archived'
        custom_410
      elsif artefact.edition.state != 'published'
        custom_404
      end
    end

    [PersonEdition].each { |type| attach_assets(@artefact, :image) if @artefact.edition.is_a?(type) }
    attach_assets(@artefact, :logo) if @artefact.edition.is_a?(OrganizationEdition)
    attach_assets(@artefact, :file) if @artefact.edition.is_a?(CreativeWorkEdition)
    attach_assets(@artefact, :thumbnail) if @artefact.edition.is_a?(CreativeWorkEdition)
    attach_assets(@artefact, :caption_file) if @artefact.edition.is_a?(VideoEdition)
    attach_assets(@artefact, :logo) if @artefact.edition.is_a?(NodeEdition)
    attach_assets(@artefact, :report) if @artefact.edition.is_a?(ReportEdition)
  end
  
  def attach_assets(artefact, *fields)
    artefact.assets ||= {}
    fields.each do |key|
      if asset_id = artefact.edition.send("#{key}_id")
        begin
          asset = asset_manager_api.asset(asset_id)
          artefact.assets[key] = asset if asset# and asset["state"] == "clean"
        rescue GdsApi::BaseError => e
          logger.warn "Requesting asset #{asset_id} returned error: #{e.inspect}"
        end
      end
    end
  end
  
  def attach_non_artefact_asset(obj, field)
    obj.assets ||= {}
    if asset_id = obj.send("#{field}_id")
      begin
        asset = asset_manager_api.asset(asset_id)
        obj.assets[field] = asset if asset# and asset["state"] == "clean"
      rescue GdsApi::BaseError => e
        logger.warn "Requesting asset #{asset_id} returned error: #{e.inspect}"
      end
    end
  end

  def asset_manager_api
    options = Object::const_defined?(:API_CLIENT_CREDENTIALS) ? API_CLIENT_CREDENTIALS : {
      bearer_token: ENV['CONTENTAPI_ASSET_MANAGER_BEARER_TOKEN']
    }
    super(options)
  end

  # Initialise statsd
  def statsd
    @statsd ||= Statsd.new("localhost").tap do |c|
      c.namespace = ENV['GOVUK_STATSD_PREFIX'].to_s
    end
  end

  def custom_404
    custom_error 404, "Resource not found"
  end

  def custom_410
    custom_error 410, "This item is no longer available"
  end

  def custom_503
    custom_error 503, "A necessary backend process was unavailable. Please try again soon."
  end

  def custom_error(code, message)
    statsd.increment("#{@statsd_scope}.error.#{code}")
    error_hash = {
      "_response_info" => {
        "status" => ERROR_CODES.fetch(code),
        "status_message" => message
      }
    }
    halt code, error_hash.to_json
  end

  def render(*args)
    statsd.time("#{@statsd_scope}.render") do
      super
    end
  end

  def verify_unpublished_permission
    warden = request.env['warden']
    return if (ENV['RACK_ENV'] == "development") && ENV['REQUIRE_AUTH'].nil?
    if warden.authenticate?
      if warden.user.has_permission?("access_unpublished")
        return true
      else
        custom_error(403, "You must be authorized to use the edition parameter")
      end
    end

    custom_error(401, "Edition parameter requires authentication")
  end
  
end
