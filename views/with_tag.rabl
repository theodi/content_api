extends "paginated"
object @result_set

node(:description) { @description }

child(:results => "results") do
  extends "_basic_artefact"
  node :details do |artefact|
    h = {
      "description" => artefact.description,
      "excerpt" => artefact.excerpt,
    }
    unless artefact.author_name.nil?
      h["author"] = {
        "name" => artefact.author_name,
        "slug" => artefact.author_slug,
        "tag_ids" => artefact.author_tag_ids
      }
    end
    if artefact.edition.respond_to?(:artist)
      h["artist"] = {
        "name" => artefact.artist_name,
        "slug" => artefact.edition.send(:artist)
      }
    end
    [:role, :course, :date, :url, :start_date, :end_date, :level, :beta, :region].each do |field|
      h[field] = artefact.edition.send(field) if artefact.edition.respond_to?(field)
    end
    if artefact.edition.respond_to?(:course)
      course = CourseEdition.where(:state => "published", :slug => artefact.edition.course).first
      h["course_title"] = course.try(:title)
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
