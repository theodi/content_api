node(:need_id) { |artefact| artefact.need_id }
node(:business_proposition) { |artefact| artefact.business_proposition }
node(:description) { |artefact| artefact.description }
node(:language) { |artefact| artefact.language }
node(:need_extended_font) { |artefact| artefact.need_extended_font }

[:body, :alternative_title, :more_information, :min_value, :max_value,
    :short_description, :introduction, :will_continue_on, :continuation_link, :link, :alternate_methods,
    :video_summary, :video_url,
    :minutes_to_complete,
    :eligibility, :evaluation, :additional_information,
    :alert_status,
    :change_description, :reviewed_at, :honorific_prefix, :honorific_suffix, :role, 
    :description, :affiliation, :url, :telephone, :twitter, :linkedin, :github, 
    :email, :length, :outline, :outcomes, :audience, :prerequisites, 
    :requirements, :materials, :subtitle, :content, :end_date, :media_enquiries_name,
    :media_enquiries_email, :media_enquiries_telephone, 
    :location, :salary, :closing_date, :joined_at, :tagline, :involvement, :want_to_meet, :case_study,
    :date_published, :length, :course, :date, :price, :trainers, :start_date, :booking_url, :hashtag, 
    :level, :region, :end_date, :beta, :join_date, :area, :host].each do |field|
  node(field, :if => lambda { |artefact| artefact.edition.respond_to?(field) }) do |artefact|
    if artefact.edition.class::GOVSPEAK_FIELDS.include?(field)
      process_content(artefact.edition.send(field))
    else
      artefact.edition.send(field)
    end
  end
end

node(:organisation, :if => lambda { |artefact| artefact.edition.respond_to?(:affiliation) && !artefact.edition.affiliation.blank? }) do |artefact|
  organisation = OrganizationEdition.where(:state => "published", :slug => artefact.edition.affiliation).first
  {
    name: organisation.try(:title),
    slug: artefact.edition.affiliation
  }
end

node(:course_title, :if => lambda { |artefact| artefact.edition.respond_to?("course") }) do |artefact|
  course = CourseEdition.where(:state => "published", :slug => artefact.edition.course).first
  course.try(:title)
end

node(:event_type, :if => lambda { |artefact| artefact.edition.is_a?(EventEdition) }) do |artefact|
  artefact.event.first.tag_id
end

node(:artist, :if => lambda { |artefact| artefact.edition.respond_to?(:artist) }) do |artefact|
  {
    name: artefact.artist_name,
    slug: artefact.edition.artist
  }
end

node(:parts, :if => lambda { |artefact| artefact.edition.respond_to?(:order_parts) }) do |artefact|
  partial("parts", object: artefact)
end

node(:nodes, :if => lambda { |artefact| artefact.edition.is_a?(SimpleSmartAnswerEdition) }) do |artefact|
  partial("smart_answer_nodes", object: artefact)
end

node(:expectations, :if => lambda { |artefact| artefact.edition.respond_to?(:expectations) }) do |artefact|
  artefact.edition.expectations.map(&:text)
end

node(nil, :if => lambda { |artefact| artefact.assets }) do |artefact|
  artefact.assets.each_with_object({}) do |(key, details), assets|
    assets[key] = {
      "web_url"      => details["file_url"],
      "versions"     => details["file_versions"],
      "content_type" => details["content_type"],
      "title"        => details["title"],
      "source"       => details["source"],
      "description"  => details["description"],
      "creator"      => details["creator"],
      "attribution"  => details["attribution"],
      "subject"      => details["subject"],
      "license"      => details["license"],
      "spatial"      => details["spatial"],
    }
  end
end
