require "presenters/minimal_artefact_presenter"

class BasicArtefactPresenter
  def initialize(artefact, url_helper)
    @artefact = artefact
    @url_helper = url_helper
  end

  def present
    presented = MinimalArtefactPresenter.new(@artefact, @url_helper).present
    presented["updated_at"] = presented_updated_date.iso8601
    presented["created_at"] = presented_created_date.iso8601
    presented["tag_ids"] = tag_ids
    presented
  end

  def tag_ids
    return {} unless @artefact.tag_ids.count > 0
    @artefact.tags.map do |tag|
      {"tag_id" => tag.id}
    end
  end

private
  # Returns the updated date that should be presented to the user
  def presented_updated_date
    # For everything else, the latest updated_at of the artefact or edition
    updated_options = [@artefact.updated_at]
    updated_options << @artefact.edition.updated_at if @artefact.edition
    updated_options.compact.max
  end

    # Returns the created date that should be presented to the user
  def presented_created_date
    @artefact.created_at
  end
end
