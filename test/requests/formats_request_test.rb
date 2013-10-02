require_relative '../test_helper'
require "gds_api/test_helpers/licence_application"
require "gds_api/test_helpers/asset_manager"

class FormatsRequestTest < GovUkContentApiTest
  include GdsApi::TestHelpers::LicenceApplication
  include GdsApi::TestHelpers::AssetManager

  def setup
    super
    @tag1 = FactoryGirl.create(:tag, tag_id: 'crime')
    @tag2 = FactoryGirl.create(:tag, tag_id: 'crime/batman')
  end

  it "should work with answer_edition" do
    artefact = FactoryGirl.create(:artefact, slug: 'batman', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    answer = FactoryGirl.create(:edition, slug: artefact.slug, body: 'Important batman information', panopticon_id: artefact.id, state: 'published')

    get '/batman.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]

    expected_fields = ['description', 'alternative_title', 'body', 'need_extended_font']

    assert_has_expected_fields(fields, expected_fields)
    assert_equal "<p>Important batman information</p>\n", fields["body"]
  end

  it "should work with business_support_edition" do
    artefact = FactoryGirl.create(:artefact, slug: 'batman', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    business_support = FactoryGirl.create(:business_support_edition, slug: artefact.slug,
                                short_description: "No policeman is going to give the Batmobile a ticket",
                                body: "batman body", eligibility: "batman eligibility", evaluation: "batman evaluation",
                                additional_information: "batman additional_information",
                                min_value: 100, max_value: 1000, panopticon_id: artefact.id, state: 'published',
                                business_support_identifier: 'enterprise-finance-guarantee', max_employees: 10,
                                organiser: "Someone", continuation_link: "http://www.example.com/scheme", will_continue_on: "Example site")
    business_support.save!

    get '/batman.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['alternative_title', 'description', 'body',
                        'short_description', 'min_value', 'max_value', 'eligibility', 'evaluation', 'additional_information',
                        'business_support_identifier', 'max_employees', 'organiser', 'continuation_link', 'will_continue_on']
    assert_has_expected_fields(fields, expected_fields)
    assert_equal "No policeman is going to give the Batmobile a ticket", fields['short_description'].strip
    assert_equal "enterprise-finance-guarantee", fields['business_support_identifier']
    assert_equal "No policeman is going to give the Batmobile a ticket", fields['short_description']
    assert_equal "<p>batman body</p>", fields['body'].strip
    assert_equal "<p>batman eligibility</p>", fields['eligibility'].strip
    assert_equal "<p>batman evaluation</p>", fields['evaluation'].strip
    assert_equal "<p>batman additional_information</p>", fields['additional_information'].strip

    assert_equal 100, fields["min_value"]
    assert_equal 1000, fields["max_value"]
    assert_equal 10, fields["max_employees"]
    assert_equal "Someone", fields["organiser"]
    assert_equal "Example site", fields["will_continue_on"]
    assert_equal "http://www.example.com/scheme", fields["continuation_link"]
  end

  it "should work with guide_edition" do
    artefact = FactoryGirl.create(:artefact, slug: 'batman', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    guide_edition = FactoryGirl.create(:guide_edition_with_two_govspeak_parts, slug: artefact.slug,
                                panopticon_id: artefact.id, state: 'published')
    guide_edition.save!

    get '/batman.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['alternative_title', 'description', 'parts']

    assert_has_expected_fields(fields, expected_fields)
    refute fields.has_key?('body')
    assert_equal "Some Part Title!", fields['parts'][0]['title']
    assert_equal "<p>This is some <strong>version</strong> text.</p>\n", fields['parts'][0]['body']
    assert_equal "#{public_web_url}/batman/part-one", fields['parts'][0]['web_url']
    assert_equal "part-one", fields['parts'][0]['slug']
  end

  it "should work with programme_edition" do
    artefact = FactoryGirl.create(:artefact, slug: 'batman', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    programme_edition = FactoryGirl.create(:programme_edition, slug: artefact.slug,
                                panopticon_id: artefact.id, state: 'published')
    programme_edition.save!

    get '/batman.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['alternative_title', 'description', 'parts']

    assert_has_expected_fields(fields, expected_fields)
    refute fields.has_key?('body')
    assert_equal "Overview", fields['parts'][0]['title']
    assert_equal "#{public_web_url}/batman/overview", fields['parts'][0]['web_url']
    assert_equal "overview", fields['parts'][0]['slug']
  end
  
  describe "person editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'batman', kind: 'person', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end
    
    it "should work with basic person edtion" do
      honorific_prefix = 'Sir'
      honorific_suffix = 'PhD'
      affiliation = 'Stately Wayne Manor'
      description = '## Foo bar'
      role = 'BATMAN!'
      url = 'http://www.batman.com'
      telephone = '1213134242'
      email = 'bat@man.com'
      twitter = 'batman'
      linkedin = 'http://www.linkedin.com/batman'
      github = 'https://github.com/batman'
      
      video_edition = FactoryGirl.create(:person_edition, title: 'Bruce Wayne', panopticon_id: @artefact.id, slug: @artefact.slug,
                                         honorific_prefix: honorific_prefix, honorific_suffix: honorific_suffix,
                                         url: url, affiliation: affiliation, role: role, telephone: telephone,
                                         email: email, twitter: twitter, linkedin: linkedin, github: github,
                                         description: description, state: 'published')

      get '/batman.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)

      fields = parsed_response["details"]

      expected_fields = %w(honorific_prefix honorific_suffix affiliation description role url telephone email twitter linkedin github)

      assert_has_expected_fields(fields, expected_fields)
      assert_equal honorific_prefix, fields["honorific_prefix"]
      assert_equal honorific_suffix, fields["honorific_suffix"]
      assert_equal affiliation, fields["affiliation"]
      assert_equal "<h2>Foo bar</h2>\n", fields["description"]
      assert_equal role, fields["role"]
      assert_equal url, fields["url"]
      assert_equal telephone, fields["telephone"]
      assert_equal email, fields["email"]
      assert_equal linkedin, fields["linkedin"]
      assert_equal github, fields["github"]
    end
    
  end
  
  describe "timed item editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'timey-wimey', kind: 'timed_item', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end

    it "should work with basic timed_item_edition" do
      content = '## Some content'
      end_date = 1.month.from_now.to_datetime
      
      timed_item_edition = FactoryGirl.create(:timed_item_edition, title: 'Timey Wimey', 
                                              panopticon_id: @artefact.id, slug: @artefact.slug,
                                              content: content, end_date: end_date, state: 'published')

      get '/timey-wimey.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)

      fields = parsed_response["details"]
      
      expected_fields = %w(content end_date)
      
      assert_has_expected_fields(fields, expected_fields)
      
      assert_equal "<h2>Some content</h2>\n", fields["content"]
      assert_equal end_date.to_s, fields["end_date"].to_s
    end
  end
  
  describe "article editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'some-news', kind: 'article', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end
    
    it "should work with basic article edition" do
      content = '## A title'
      url = 'http://www.example.com'
      media_enquiries_name = 'Dave'
      media_enquiries_email = 'dave@example.com'
      media_enquiries_telephone = '1212312321'
      
      article_edition = FactoryGirl.create(:article_edition, title: 'Here is the news', 
                                            panopticon_id: @artefact.id, slug: @artefact.slug,
                                            content: content, url: url, media_enquiries_name: media_enquiries_name,
                                            media_enquiries_email: media_enquiries_email, media_enquiries_telephone: media_enquiries_telephone,
                                            state: 'published')
                                            
      get '/some-news.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)

      fields = parsed_response["details"]

      expected_fields = %w(content url media_enquiries_name media_enquiries_email media_enquiries_telephone)
      
      assert_has_expected_fields(fields, expected_fields)
      
      assert_equal "<h2>A title</h2>\n", fields["content"]
      assert_equal media_enquiries_name, fields["media_enquiries_name"]
      assert_equal media_enquiries_email, fields["media_enquiries_email"]
      assert_equal media_enquiries_telephone, fields["media_enquiries_telephone"]
    end
  end
  
  describe "case study editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'case-study', kind: 'case_study', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end
    
    it "should work with basic case study edition" do
      content = '## A case title'
      url = 'http://www.example.com/case'
      media_enquiries_name = 'Casey Jones'
      media_enquiries_email = 'casey@example.com'
      media_enquiries_telephone = '342343534534'
      
      article_edition = FactoryGirl.create(:case_study_edition, title: 'Studying your cases', 
                                            panopticon_id: @artefact.id, slug: @artefact.slug,
                                            content: content, url: url, media_enquiries_name: media_enquiries_name,
                                            media_enquiries_email: media_enquiries_email, media_enquiries_telephone: media_enquiries_telephone,
                                            state: 'published')
                                            
      get '/case-study.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)

      fields = parsed_response["details"]

      expected_fields = %w(content url media_enquiries_name media_enquiries_email media_enquiries_telephone)
      
      assert_has_expected_fields(fields, expected_fields)
      
      assert_equal "<h2>A case title</h2>\n", fields["content"]
      assert_equal media_enquiries_name, fields["media_enquiries_name"]
      assert_equal media_enquiries_email, fields["media_enquiries_email"]
      assert_equal media_enquiries_telephone, fields["media_enquiries_telephone"]
    end
  end
  
  describe "FAQ editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'meaning-of-life', kind: 'faq', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end
    
    it "should work with basic FAQ edition" do
      content = "**42**"

      article_edition = FactoryGirl.create(:faq_edition, title: 'What is the meaning of life?', 
                                            panopticon_id: @artefact.id, slug: @artefact.slug,
                                            content: content, state: 'published')

      get '/meaning-of-life.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)
      
      expected_fields = %w(content)
      
      fields = parsed_response["details"]
      
      assert_has_expected_fields(fields, expected_fields)
      
      assert_equal "<p><strong>42</strong></p>\n", fields["content"]
    end
  end

  describe "Job editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'jobby-job', kind: 'job', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end
    
    it "should work with basic job edition" do
      location = 'The Moon'
      salary = '20p/decade'
      description = 'Live on the moon'
      closing_date = 1.month.from_now

      article_edition = FactoryGirl.create(:job_edition, title: 'The job of a lifetime', 
                                            panopticon_id: @artefact.id, slug: @artefact.slug,
                                            location: location, salary: salary,
                                            description: description, closing_date: closing_date,
                                            state: 'published')

      get '/jobby-job.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)
      
      expected_fields = %w(location salary description closing_date)
      
      fields = parsed_response["details"]
      
      assert_has_expected_fields(fields, expected_fields)
      
      assert_equal location, fields["location"]
      assert_equal salary, fields["salary"]
      assert_equal "<p>Live on the moon</p>\n", fields["description"]
      assert_equal closing_date.to_s, fields["closing_date"].to_s
    end
  end

  describe "video editions" do
    before :each do
      @artefact = FactoryGirl.create(:artefact, slug: 'batman', kind: 'video', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    end

    it "should work with basic video_edition" do
      video_edition = FactoryGirl.create(:video_edition, title: 'Video killed the radio star', panopticon_id: @artefact.id, slug: @artefact.slug,
                                         video_summary: 'I am a video summary', video_url: 'http://somevideourl.com',
                                         body: "Video description\n------", state: 'published')

      get '/batman.json'
      parsed_response = JSON.parse(last_response.body)

      assert last_response.ok?
      assert_base_artefact_fields(parsed_response)

      fields = parsed_response["details"]

      expected_fields = %w(alternative_title description video_url video_summary body)

      assert_has_expected_fields(fields, expected_fields)
      assert_equal "I am a video summary", fields["video_summary"]
      assert_equal "http://somevideourl.com", fields["video_url"]
      assert_equal "<h2>Video description</h2>\n", fields["body"]
    end

    describe "loading the caption_file from asset-manager" do
      it "should include the caption_file details" do
        edition = FactoryGirl.create(:video_edition, :slug => @artefact.slug,
                                     :panopticon_id => @artefact.id, :state => "published",
                                     :caption_file_id => "512c9019686c82191d000001")

        asset_manager_has_an_asset("512c9019686c82191d000001", {
          "id" => "http://asset-manager.#{ENV["GOVUK_APP_DOMAIN"]}/assets/512c9019686c82191d000001",
          "name" => "captions-file.xml",
          "content_type" => "application/xml",
          "file_url" => "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/captions-file.xml",
          "state" => "clean",
        })

        get "/batman.json"
        assert last_response.ok?
        assert_status_field "ok", last_response

        parsed_response = JSON.parse(last_response.body)
        caption_file_info = {
          "web_url"=>"https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/captions-file.xml",
          "content_type"=>"application/xml",
          "title"=>nil, 
          "source"=>nil, 
          "description"=>nil, 
          "creator"=>nil, 
          "attribution"=>nil, 
          "subject"=>nil, 
          "license"=>nil, 
          "spatial"=>nil
        }
        assert_equal caption_file_info, parsed_response["details"]["caption_file"]
      end

      it "should gracefully handle failure to reach asset-manager" do
        edition = FactoryGirl.create(:video_edition, :slug => @artefact.slug,
                                     :panopticon_id => @artefact.id, :state => "published",
                                     :caption_file_id => "512c9019686c82191d000001")

        stub_request(:get, "http://asset-manager.#{ENV["GOVUK_APP_DOMAIN"]}/assets/512c9019686c82191d000001").to_return(:body => "Error", :status => 500)

        get '/batman.json'
        assert last_response.ok?

        parsed_response = JSON.parse(last_response.body)
        assert_base_artefact_fields(parsed_response)

        refute parsed_response["details"].has_key?("caption_file")
      end

      it "should not blow up with an type mismatch between the artefact and edition" do
        # This can happen when a format is being changed, and the draft edition is being preview
        edition = FactoryGirl.create(:answer_edition, :slug => @artefact.slug,
                                     :panopticon_id => @artefact.id, :state => "published")

        get '/batman.json'
        assert last_response.ok?
      end
    end
  end

  it "should work with licence_edition" do
    artefact = FactoryGirl.create(:artefact, slug: 'batman-licence', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    licence_edition = FactoryGirl.create(:licence_edition, slug: artefact.slug, licence_short_description: 'Batman licence',
                                licence_overview: 'Not just anyone can be Batman', panopticon_id: artefact.id, state: 'published',
                                will_continue_on: 'The Batman', continuation_link: 'http://www.batman.com', licence_identifier: "123-4-5")
    licence_exists('123-4-5', { })

    get '/batman-licence.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['alternative_title', 'licence_overview', 'licence_short_description', 'licence_identifier', 'will_continue_on', 'continuation_link']

    assert_has_expected_fields(fields, expected_fields)
    assert_equal "<p>Not just anyone can be Batman</p>", fields["licence_overview"].strip
    assert_equal "Batman licence", fields["licence_short_description"]
    assert_equal "123-4-5", fields["licence_identifier"]
    assert_equal "The Batman", fields["will_continue_on"]
    assert_equal "http://www.batman.com", fields["continuation_link"]
  end

  it "should work with local_transaction_edition" do
    service = FactoryGirl.create(:local_service, lgsl_code: 42)
    expectation = FactoryGirl.create(:expectation)
    artefact = FactoryGirl.create(:artefact, slug: 'batman-transaction', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    local_transaction_edition = FactoryGirl.create(:local_transaction_edition, slug: artefact.slug, lgsl_code: 42, lgil_override: 3345,
                                expectation_ids: [expectation.id], minutes_to_complete: 3,
                                introduction: "batman introduction", more_information: "batman more_information",
                                panopticon_id: artefact.id, state: 'published')
    get '/batman-transaction.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['alternative_title', 'lgsl_code', 'lgil_override', 'introduction', 'more_information',
                        'minutes_to_complete', 'expectations']

    assert_has_expected_fields(fields, expected_fields)
    assert_equal "<p>batman introduction</p>", fields["introduction"].strip
    assert_equal "<p>batman more_information</p>", fields["more_information"].strip
    assert_equal "3", fields["minutes_to_complete"]
    assert_equal 42, fields["lgsl_code"]
    assert_equal 3345, fields["lgil_override"]
  end

  it "should work with transaction_edition" do
    expectation = FactoryGirl.create(:expectation)
    artefact = FactoryGirl.create(:artefact, slug: 'batman-transaction', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    transaction_edition = FactoryGirl.create(:transaction_edition, slug: artefact.slug,
                                expectation_ids: [expectation.id], minutes_to_complete: 3,
                                introduction: "batman introduction", more_information: "batman more_information",
                                alternate_methods: "batman alternate_methods",
                                will_continue_on: "A Site", link: "http://www.example.com/foo",
                                panopticon_id: artefact.id, state: 'published')
    get '/batman-transaction.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['alternate_methods', 'will_continue_on', 'link', 'introduction', 'more_information',
                        'expectations']

    assert_has_expected_fields(fields, expected_fields)
    assert_equal "<p>batman introduction</p>", fields["introduction"].strip
    assert_equal "<p>batman more_information</p>", fields["more_information"].strip
    assert_equal "<p>batman alternate_methods</p>", fields["alternate_methods"].strip
    assert_equal "3", fields["minutes_to_complete"]
    assert_equal "A Site", fields["will_continue_on"]
    assert_equal "http://www.example.com/foo", fields["link"]
  end

  it "should work with place_edition" do
    expectation = FactoryGirl.create(:expectation)
    artefact = FactoryGirl.create(:artefact, slug: 'batman-place', owning_app: 'publisher', sections: [@tag1.tag_id], state: 'live')
    place_edition = FactoryGirl.create(:place_edition, slug: artefact.slug, expectation_ids: [expectation.id],
                                introduction: "batman introduction", more_information: "batman more_information",
                                place_type: "batman-locations",
                                minutes_to_complete: 3, panopticon_id: artefact.id, state: 'published')
    get '/batman-place.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_base_artefact_fields(parsed_response)

    fields = parsed_response["details"]
    expected_fields = ['introduction', 'more_information', 'place_type', 'expectations']

    assert_has_expected_fields(fields, expected_fields)
    assert_equal "<p>batman introduction</p>", fields["introduction"].strip
    assert_equal "<p>batman more_information</p>", fields["more_information"].strip
    assert_equal "batman-locations", fields["place_type"]
  end

  it "should work with simple smart-answers" do
    artefact = FactoryGirl.create(:artefact, :slug => 'the-bridge-of-death', :owning_app => 'publisher', :state => 'live')
    smart_answer = FactoryGirl.build(:simple_smart_answer_edition, :panopticon_id => artefact.id, :state => 'published',
                        :body => "STOP!\n-----\n\nHe who would cross the Bridge of Death  \nMust answer me  \nThese questions three  \nEre the other side he see.\n")

    n = smart_answer.nodes.build(:kind => 'question', :slug => 'what-is-your-name', :title => "What is your name?", :order => 1)
    n.options.build(:label => "Sir Lancelot of Camelot", :next_node => 'what-is-your-favorite-colour', :order => 1)
    n.options.build(:label => "Sir Galahad of Camelot", :next_node => 'what-is-your-favorite-colour', :order => 3)
    n.options.build(:label => "Sir Robin of Camelot", :next_node => 'what-is-the-capital-of-assyria', :order => 2)

    n = smart_answer.nodes.build(:kind => 'question', :slug => 'what-is-your-favorite-colour', :title => "What is your favorite colour?", :order => 3)
    n.options.build(:label => "Blue", :next_node => 'right-off-you-go')
    n.options.build(:label => "Blue... NO! YELLOOOOOOOOOOOOOOOOWWW!!!!", :next_node => 'arrrrrghhhh')

    n = smart_answer.nodes.build(:kind => 'question', :slug => 'what-is-the-capital-of-assyria', :title => "What is the capital of Assyria?", :order => 2)
    n.options.build(:label => "I don't know THAT!!", :next_node => 'arrrrrghhhh')

    n = smart_answer.nodes.build(:kind => 'outcome', :slug => 'right-off-you-go', :title => "Right, off you go.", :body => "Oh! Well, thank you.  Thank you very much", :order => 4)
    n = smart_answer.nodes.build(:kind => 'outcome', :slug => 'arrrrrghhhh', :title => "AAAAARRRRRRRRRRRRRRRRGGGGGHHH!!!!!!!", :order => 5)
    smart_answer.save!

    get '/the-bridge-of-death.json'
    assert_equal 200, last_response.status

    parsed_response = JSON.parse(last_response.body)
    assert_base_artefact_fields(parsed_response)
    details = parsed_response["details"]

    assert_has_expected_fields(details, %w(body nodes))
    assert_equal "<h2>STOP!</h2>\n\n<p>He who would cross the Bridge of Death<br />\nMust answer me<br />\nThese questions three<br />\nEre the other side he see.</p>", details["body"].strip

    nodes = details["nodes"]

    assert_equal ["What is your name?", "What is the capital of Assyria?", "What is your favorite colour?", "Right, off you go.", "AAAAARRRRRRRRRRRRRRRRGGGGGHHH!!!!!!!" ], nodes.map {|n| n["title"]}

    question1 = nodes[0]
    assert_equal "question", question1["kind"]
    assert_equal "what-is-your-name", question1["slug"]
    assert_equal ["Sir Lancelot of Camelot", "Sir Robin of Camelot", "Sir Galahad of Camelot"], question1["options"].map {|o| o["label"]}
    assert_equal ["sir-lancelot-of-camelot", "sir-robin-of-camelot", "sir-galahad-of-camelot"], question1["options"].map {|o| o["slug"]}
    assert_equal ["what-is-your-favorite-colour", "what-is-the-capital-of-assyria", "what-is-your-favorite-colour"], question1["options"].map {|o| o["next_node"]}

    outcome1 = nodes[3]
    assert_equal "outcome", outcome1["kind"]
    assert_equal "right-off-you-go", outcome1["slug"]
    assert_equal "<p>Oh! Well, thank you.  Thank you very much</p>", outcome1["body"].strip
  end
end
