require "presenters/basic_artefact_presenter"

class RelatedArtefactPresenter
  def initialize(artefact, url_helper)
    @artefact = artefact
    @url_helper = url_helper
  end

  def present
    presented = BasicArtefactPresenter.new(@artefact, @url_helper).present
    presented["extras"] = extras if has_extras?
    presented
  end

  private

  def extras
    edition = @artefact.editions.last
    {
      "start_date" => edition.start_date,
      "end_date" => edition.end_date,
      "location" => edition.location
    }
  end

  def has_extras?
    @artefact.editions.count > 0 && @artefact.editions.last.is_a?(EventEdition)
  end

end
