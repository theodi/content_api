extends "paginated"
object @result_set

node(:description) { @description }

child(:results => "results") do
  extends "_basic_artefact"
  node :details do |artefact|
    h = {
      "description" => artefact.description,
      "excerpt" => artefact.excerpt,
      "author" => {
        "name" => artefact.author_name,
        "slug" => artefact.author_slug
      }
    }
    [:role].each do |field|
      h[field] = artefact.edition.send(field) if artefact.edition.respond_to?(field)
    end
    if artefact.assets
      artefact.assets.each_with_object({}) do |(key, details), assets|
        details["file_versions"].each do |version, url|
          h[version] = url
        end
      end
    end
    h
  end
end
