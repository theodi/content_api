require "presenters/minimal_artefact_presenter"

class BasicArtefactPresenter
  def initialize(artefact, url_helper)
    @artefact = artefact
    @url_helper = url_helper
  end

  def present
    presented = MinimalArtefactPresenter.new(@artefact, @url_helper).present
    presented["updated_at"] = presented_updated_date.iso8601
    presented["group"] = @artefact.group if @artefact.group.present?
    presented
  end

private
  # Returns the updated date that should be presented to the user
  def presented_updated_date
    # For everything else, the latest updated_at of the artefact or edition
    updated_options = [@artefact.updated_at]
    updated_options << @artefact.edition.updated_at if @artefact.edition
    updated_options.compact.max
  end
end