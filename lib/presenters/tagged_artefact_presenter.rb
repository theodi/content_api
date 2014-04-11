require "presenters/artefact_presenter"

class TaggedArtefactPresenter
  def initialize(artefact, url_helper, options={})
    @artefact = artefact
    @url_helper = url_helper
    @govspeak_formatter = options[:govspeak_formatter]
    @options = options
  end

  def present
    presented = ArtefactPresenter.new(@artefact, @url_helper, GovspeakFormatter.new(:html, nil)).present
    if @options["whole_body"]
      presented["details"]["body"] = @artefact.whole_body
    end

    presented
  end
end
