extends "paginated"
object @result_set

node(:description) { @description }

child(:results => "results") do
  extends "_basic_artefact"
  node :details do |artefact|
    h = {
      "description" => artefact.description,
      "excerpt" => artefact.excerpt
    }
    [:role].each do |field|
      h[field] = artefact.edition.send(field) if artefact.edition.respond_to?(field)
    end
    h
  end
end
