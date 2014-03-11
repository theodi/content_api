require "presenters/basic_artefact_presenter"
require "presenters/tag_presenter"
require "presenters/artefact_part_presenter"
require "presenters/artefact_author_presenter"
require "presenters/artefact_node_presenter"
require "presenters/artefact_organization_presenter"


class ArtefactPresenter

  BASE_FIELDS = %w(
    need_id business_proposition description language need_extended_font
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

    presented["tags"] = present_with(@artefact.tags, TagPresenter)
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
      assets
    ].inject(&:merge)

    presented["author"] = author
    presented["nodes"] = nodes
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
    fields = OPTIONAL_FIELDS.select { |f| @artefact.edition.respond_to?(f) }
    Hash[fields.map do |field|
      field_value = @artefact.edition.send(field)

      if @artefact.edition.class::GOVSPEAK_FIELDS.include?(field)
        [field, @govspeak_formatter.format(field_value)]
      else
        [field, field_value]
      end
    end]
  end

  def author
    return {} unless @artefact.author_edition
    {"author" => ArtefactAuthorPresenter.new(
        @artefact,
        @url_helper
      ).present
    }
  end

  def nodes
    return {} unless @artefact.node_editions

    presented_nodes = @artefact.node_editions.map do |node|
      ArtefactNodePresenter.new(
        node,
        @url_helper
      ).present
    end

    {"nodes" => presented_nodes}
  end

  def organizations
    return {} unless @artefact.organization_editions

    presented_organizations = @artefact.organization_editions.map do |org|
      ArtefactOrganizationPresenter.new(
        org,
        @url_helper
      ).present
    end

    {"organizations" => presented_organizations}
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

    {"nodes" => presented_nodes}
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
        "content_type" => details["content_type"],
      }
    end
  end

end
