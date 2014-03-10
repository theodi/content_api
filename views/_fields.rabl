node(:need_id) { |artefact| artefact.need_id }
node(:business_proposition) { |artefact| artefact.business_proposition }
node(:description) { |artefact| artefact.description }
node(:language) { |artefact| artefact.language }
node(:need_extended_font) { |artefact| artefact.need_extended_font }

[:body, :alternative_title, :more_information, :min_value, :max_value,
    :short_description, :introduction, :will_continue_on, :continuation_link, :link, :alternate_methods,
    :video_summary, :video_url,
    :lgsl_code, :lgil_override, :minutes_to_complete, :place_type,
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

node(:places, :if => lambda { |artefact| artefact.places }) do |artefact|
  if artefact.places.first && artefact.places.first["error"]
    [
      { error: artefact.places.first["error"] }
    ]
  else
    artefact.places.map do |place|
      [:name, :address1, :address2, :town, :postcode, 
          :email, :phone, :text_phone, :fax, 
          :access_notes, :general_notes, :url,
          :location].each_with_object({}) do |field_name, hash|
        hash[field_name.to_s] = place[field_name.to_s]
      end
    end
  end
end

node(:local_authority, :if => lambda { |artefact| artefact.edition.is_a?(LocalTransactionEdition) && params[:snac] }) do |artefact|
  provider = artefact.edition.service.preferred_provider(params[:snac])
  partial("_local_authority", object: provider)
end

node(:local_interaction, :if => lambda { |artefact| artefact.edition.is_a?(LocalTransactionEdition) && params[:snac] }) do |artefact|
  provider = artefact.edition.service.preferred_provider(params[:snac])
  if provider
    interaction = provider.preferred_interaction_for(artefact.edition.lgsl_code, artefact.edition.lgil_override)
    partial("_local_interaction", object: interaction)
  end
end

node(:local_service, :if => lambda { |artefact| artefact.edition.respond_to?(:service) }) do |artefact|
  partial("local_service", object: artefact.edition.service)
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

node(:country, :if => lambda { |artefact| artefact.country.is_a?(Country) }) do |artefact|
  {
    "name" => artefact.country.name,
    "slug" => artefact.country.slug,
  }
end

node(:countries, :if => lambda { |artefact| @countries and artefact.slug == 'foreign-travel-advice' }) do |artefact|
  @countries.map do |c|
    {
      :id => country_url(c),
      :name => c.name,
      :identifier => c.slug,
      :web_url => country_web_url(c),
      :updated_at => (c.edition.published_at || c.edition.updated_at).iso8601,
      :change_description => c.edition.change_description,
      :synonyms => c.edition.synonyms,
    }
  end
end
