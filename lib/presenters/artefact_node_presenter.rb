class ArtefactNodePresenter
  def initialize(node, url_helper)
    @node = node
    @url_helper = url_helper
  end

  def present
    {
      name: @node.title,
      slug: @node.slug,
      level: @node.level,
      beta: @node.beta,
      web_url: @url_helper.artefact_web_url(@node.artefact)
    }
  end
end
