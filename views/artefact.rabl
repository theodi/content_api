object false

node :_response_info do
  { status: "ok" }
end

glue @artefact do
  extends "_basic_artefact"
end

child @artefact => :details do
  extends "_fields"
end

child @artefact.tags => :tags do
  extends "_tag"
end

child @artefact.live_related_artefacts => :related do
  extends "_basic_artefact"
end

node :author do
  if @author
    {
      name: @author.title,
      slug: @author.slug,
      web_url: artefact_web_url(@author.artefact),
      tag_ids: @author.artefact.tag_ids
    }
  else
    nil
  end
end

node(:related_external_links) do
  @artefact.external_links.map do |link|
    {
      :title => link.title,
      :url => link.url,
    }
  end
end
