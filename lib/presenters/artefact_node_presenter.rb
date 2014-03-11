class ArtefactNodePresenter
  def initialize(node, url_helper)
    @node = node
    @url_helper = url_helper
  end

  def present
    {
      name: @author.title,
      slug: @author.slug,
      web_url: artefact_web_url(@author.artefact),
      tag_ids: @author.artefact.tag_ids
    }
  end
end
