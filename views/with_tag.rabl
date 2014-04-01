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
    if params[:whole_body]
      h["body"] = artefact.whole_body
    end
    if artefact.author_edition
      h["author"] = {
        "name" => artefact.author_edition.title,
        "slug" => artefact.author_edition.slug,
        "tag_ids" => artefact.author_edition.artefact.tag_ids
      }
    end
    unless artefact.node_editions.empty?
      h["nodes"] = artefact.node_editions.map do |node|
        {
          "name" => node.title,
          "slug" => node.slug,
          "level" => node.level,
          "beta" => node.beta,
        }
      end
    end
    unless artefact.organization_editions.empty?
      h["organizations"] = artefact.organization_editions.map do |org|
        {
          "name" => org.title,
          "slug" => org.slug,
        }
      end
    end
    if artefact.edition.respond_to?(:artist)
      h["artist"] = {
        "name" => artefact.artist_name,
        "slug" => artefact.edition.send(:artist)
      }
    end
    [:role, :course, :date, :url, :start_date, :end_date, :level, :beta, :region, :location].each do |field|
      h[field] = artefact.edition.send(field) if artefact.edition.respond_to?(field)
    end
    if artefact.edition.respond_to?(:course)
      course = CourseEdition.where(:state => "published", :slug => artefact.edition.course).first
      h["course_title"] = course.try(:title)
    end
    if artefact.edition.respond_to?(:affiliation) && !artefact.edition.affiliation.blank?
      organisation = OrganizationEdition.where(:state => "published", :slug => artefact.edition.affiliation).first
      h["organisation"] = {}
      h["organisation"]["name"] = organisation.try(:title)
      h["organisation"]["slug"] = artefact.edition.affiliation
    end
    if artefact.kind == "event"
      h["event_type"] = artefact.event.first.tag_id
    end
    if artefact.assets
      artefact.assets.each_with_object({}) do |(key, details), assets|
        h["web_url"] = details['file_url']
        details["file_versions"].each do |version, url|
          h[version] = url
        end
      end
    end
    h
  end
end
