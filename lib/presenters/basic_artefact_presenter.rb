require "presenters/minimal_artefact_presenter"

# Common base presenter for artefacts, including some edition-related
# information such as update dates.
#
# Also presents the `group` field for grouping related artefacts together.
class BasicArtefactPresenter
  def initialize(artefact, url_helper)
    @artefact = artefact
    @url_helper = url_helper
  end

  def present
    presented = MinimalArtefactPresenter.new(@artefact, @url_helper).present
    presented["updated_at"] = presented_updated_date.iso8601
    presented["created_at"] = presented_created_date.iso8601
    presented["tag_ids"] = @artefact.scoped_tag_ids
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

    # Returns the created date that should be presented to the user
  def presented_created_date
    @artefact.created_at
  end
end
