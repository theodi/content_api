class ArtefactOrganizationPresenter
  def initialize(organization, url_helper)
    @organization = organization
    @url_helper = url_helper
  end

  def present
    {
      name: @organization.title,
      slug: @organization.slug,
      web_url: @url_helper.artefact_web_url(@organization.artefact)
    }
  end
end
