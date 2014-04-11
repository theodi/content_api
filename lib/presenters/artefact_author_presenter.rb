class ArtefactAuthorPresenter
  def initialize(author, url_helper)
    @author = author
    @url_helper = url_helper
  end

  def present
    {
      name: @author.title,
      slug: @author.slug,
      web_url: @url_helper.artefact_web_url(@author.artefact),
      tag_ids: @author.artefact.scoped_tag_ids
    }
  end
end
