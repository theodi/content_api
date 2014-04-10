require "presenters/basic_artefact_presenter"
require "presenters/tag_presenter"
require "presenters/artefact_part_presenter"
require "presenters/artefact_author_presenter"
require "presenters/artefact_node_presenter"
require "presenters/artefact_organization_presenter"
# Full presenter for artefacts.
#
# This presenter handles all relevant fields for the various different types of
# artefact, so it's pretty expensive and so we only use this for a single
# artefact's view (the `*.json` handler in `govuk_content_api.rb`).
class ArtefactPresenter

  BASE_FIELDS = %w(
    need_id business_proposition description excerpt language need_extended_font
  ).map(&:to_sym)

  OPTIONAL_FIELDS = %w(
    additional_information
    alternate_methods
    alternative_title
    body
    change_description
    introduction
    link
    more_information
    organiser
    place_type
    reviewed_at
    short_description
    summary
    video_summary
    video_url
  ).map(&:to_sym)

  ODI_FIELDS = %w(
    honorific_prefix
    honorific_suffix
    role
    description
    affiliation
    url
    telephone
    twitter
    linkedin
    github
    email
    length
    outline
    outcomes
    audience
    prerequisites
    requirements
    materials
    subtitle
    content
    end_date
    media_enquiries_name
    media_enquiries_email
    media_enquiries_telephone
    location
    salary
    closing_date
    joined_at
    tagline
    involvement
    want_to_meet
    case_study
    date_published
    course
    date
    price
    trainers
    start_date
    booking_url
    hashtag
    level
    region
    end_date
    beta
    join_date
    area
    host
  ).map(&:to_sym)

  def initialize(artefact, url_helper, govspeak_formatter)
    @artefact = artefact
    @url_helper = url_helper
    @govspeak_formatter = govspeak_formatter
  end

  def present_with(items, presenter_class)
    items.map do |item|
      presenter_class.new(item, @url_helper).present
    end
  end

  def present
    presented = BasicArtefactPresenter.new(@artefact, @url_helper).present
    scoped_tags = @artefact.tags.reject {|t| t.tag_type == 'role'}
    presented["tags"] = present_with(scoped_tags, TagPresenter)
    presented["related"] = present_with(
      @artefact.live_related_artefacts,
      BasicArtefactPresenter
    )

    # MERGE ALL THE THINGS!
    presented["details"] = [
      base_fields,
      optional_fields,
      parts,
      smart_answer_nodes,
      expectations,
      assets,
      organisation,
      course_title,
      event_type,
    ].inject(&:merge)

    # TODO:there is duplication in representing this data, I don't know why
    # check in frontend which one is actually used so we can come back and clean this up
    presented["details"]["organizations"] = organizations

    presented["details"]["author"] = author
    presented["author"] = author

    presented["nodes"] = nodes
    presented["details"]["nodes"] = nodes

    presented["organizations"] = organizations

    presented["related_external_links"] = @artefact.external_links.map do |l|
      {
        "title" => l.title,
        "url" => l.url
      }
    end

    presented
  end

private
  def base_fields
    Hash[BASE_FIELDS.map do |field|
      [field, @artefact.send(field)]
    end]
  end

  def optional_fields
    all_optional_fields = ODI_FIELDS + OPTIONAL_FIELDS
    fields = all_optional_fields.select { |f| @artefact.edition.respond_to?(f) }
    Hash[fields.map do |field|
      field_value = @artefact.edition.send(field)

      if @artefact.edition.class::GOVSPEAK_FIELDS.include?(field)
        [field, @govspeak_formatter.format(field_value)]
      else
        [field, field_value]
      end
    end]
  end

  def organisation
    return {} unless @artefact.edition.respond_to?(:affiliation) && !@artefact.edition.affiliation.blank?
     organisation = OrganizationEdition.where(
        :state => "published", :slug => @artefact.edition.affiliation
      ).first
    {
      "organisation" => {
        name: organisation.try(:title),
        slug: @artefact.edition.affiliation
      }
    }
  end

  def course_title
    return {} unless @artefact.edition.respond_to?("course")
    course = CourseEdition.where(
        :state => "published", :slug => @artefact.edition.course
      ).first
    {"course_title" => course.try(:title)}
  end

  def event_type
  return {} unless @artefact.edition.is_a?(EventEdition)
    {"event_type" => @artefact.event.first.tag_id}
  end

  def author
    return {} unless @artefact.author_edition
    presenter = ArtefactAuthorPresenter.new(
      @artefact.author_edition,
      @url_helper
    ).present
  end

  def nodes
    return [] if @artefact.node_editions.empty?

    presented_nodes = @artefact.node_editions.map do |node|
      ArtefactNodePresenter.new(
        node,
        @url_helper
      ).present
    end
  end

  def organizations
    return {} unless @artefact.organization_editions

    presented_organizations = @artefact.organization_editions.map do |org|
      ArtefactOrganizationPresenter.new(
        org,
        @url_helper
      ).present
    end
  end

  def parts
    return {} unless @artefact.edition.respond_to?(:order_parts)

    presented_parts = @artefact.edition.order_parts.map do |part|
      ArtefactPartPresenter.new(
        @artefact,
        part,
        @url_helper,
        @govspeak_formatter
      ).present
    end

    {"parts" => presented_parts}
  end

  def smart_answer_nodes
    return {} unless @artefact.edition.is_a?(SimpleSmartAnswerEdition)

    presented_nodes = @artefact.edition.nodes.map do |n|
      {
        "kind" => n.kind,
        "slug" => n.slug,
        "title" => n.title,
        "body" => @govspeak_formatter.format(n.body),
        "options" => n.options.map { |o|
          {
            "label" => o.label,
            "slug" => o.slug,
            "next_node" => o.next_node,
          }
        }
      }
    end

    {"smart_answer_nodes" => {"nodes" => presented_nodes}}
  end

  def expectations
    return {} unless @artefact.edition.respond_to?(:expectations)

    {
      "expectations" => @artefact.edition.expectations.map(&:text) 
    }
  end

  def assets
    return {} unless @artefact.assets

    @artefact.assets.each_with_object({}) do |(key, details), assets|
      assets[key] = {
        "web_url" => details["file_url"],
        "versions"     => details["file_versions"],
        "content_type" => details["content_type"],
        "title"        => details["title"],
        "source"       => details["source"],
        "description"  => details["description"],
        "creator"      => details["creator"],
        "attribution"  => details["attribution"],
        "subject"      => details["subject"],
        "license"      => details["license"],
        "spatial"      => details["spatial"]
      }
    end
  end

end
