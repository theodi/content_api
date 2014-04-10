require 'test_helper'
require 'uri'
require 'gds_api/test_helpers/fact_cave'

class ArtefactRequestTest < GovUkContentApiTest
  include GdsApi::TestHelpers::FactCave

  def bearer_token_for_user_with_permission
    { 'HTTP_AUTHORIZATION' => 'Bearer xyz_has_permission_xyz' }
  end
  
  def bearer_token_for_user_without_permission
    { 'HTTP_AUTHORIZATION' => 'Bearer xyz_does_not_have_permission_xyz' }
  end
  
  it "should return 404 if artefact not found" do
    get '/bad-artefact.json'
    assert last_response.not_found?
    assert_status_field "not found", last_response
  end
  
  it "should return 404 if artefact in draft" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'draft')  
    get "/#{artefact.slug}.json"
    assert last_response.not_found?
    assert_status_field "not found", last_response
  end
  
  it "should return 410 if artefact archived" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'archived')
    get "/#{artefact.slug}.json"
    assert_equal 410, last_response.status
    assert_status_field "gone", last_response
  end
  
  describe "returning related artefacts" do
    it "should return related artefacts" do
      related_artefacts = [
        FactoryGirl.create(:my_artefact, slug: "related-artefact-1", name: "Pies", state: 'live'),
        FactoryGirl.create(:my_artefact, slug: "related-artefact-2", name: "Cake", state: 'live')
      ]
  
      artefact = FactoryGirl.create(:my_non_publisher_artefact, related_artefacts: related_artefacts, state: 'live')
  
      get "/#{artefact.slug}.json"
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal 200, last_response.status
  
      assert_equal 2, parsed_response["related"].length
  
      related_artefacts.zip(parsed_response["related"]).each do |response_artefact, related_info|
        assert_equal response_artefact.name, related_info["title"]
        artefact_path = "/#{CGI.escape(response_artefact.slug)}.json"
        assert_equal artefact_path, URI.parse(related_info["id"]).path
        assert_equal "#{public_web_url}/#{response_artefact.slug}", related_info["web_url"]
      end
    end
  
    it "should include related artefacts in their related order, not the natural order" do
      a = FactoryGirl.create(:my_artefact, name: "A", state: 'live')
      b = FactoryGirl.create(:my_artefact, name: "B", state: 'live')
  
      artefact = FactoryGirl.create(:my_non_publisher_artefact, related_artefacts: [b, a], state: 'live')
  
      get "/#{artefact.slug}.json"
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal ["B", "A"], parsed_response["related"].map { |r| r["title"] }
    end
  
    it "should exclude unpublished related artefacts" do
      related_artefacts = [
        FactoryGirl.create(:my_artefact, state: 'draft'),
        live = FactoryGirl.create(:my_artefact, state: 'live'),
        FactoryGirl.create(:my_artefact, state: 'archived')
      ]
  
      artefact = FactoryGirl.create(:my_non_publisher_artefact, related_artefacts: related_artefacts,
          state: 'live', slug: "workaround")
  
      get "/#{artefact.slug}.json"
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal 200, last_response.status
  
      assert_equal 1, parsed_response["related"].length
  
      assert_equal "http://example.org/#{live.slug}.json", parsed_response['related'][0]["id"]
    end
  
    it "should return an empty list if there are no related artefacts" do
      artefact = FactoryGirl.create(:my_non_publisher_artefact, related_artefacts: [], state: 'live')
  
      get "/#{artefact.slug}.json"
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal 200, last_response.status
  
      assert_equal [], parsed_response["related"]
    end
  end
  
  describe "returning related external links" do
    before :each do
      @artefact = FactoryGirl.create(:my_non_publisher_artefact, :state => 'live')
    end
  
    it "should return an array of external links" do
      @artefact.external_links.build(:title => "Fooey", :url => "http://www.example.com/fooey")
      @artefact.external_links.build(:title => "Gooey", :url => "https://www.example.org/index.html?id=gooey")
      @artefact.external_links.build(:title => "Kablooie", :url => "https://www.example.com/kablooie")
      @artefact.save!
  
      get "/#{@artefact.slug}.json"
      assert_equal 200, last_response.status
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal %w(Fooey Gooey Kablooie), parsed_response["related_external_links"].map {|l| l["title"] }
    end
  
    it "should return empty array is there are no external links" do
      get "/#{@artefact.slug}.json"
      assert_equal 200, last_response.status
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal [], parsed_response["related_external_links"]
    end
  end
  
  it "should not look for edition if publisher not owner" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
  
    get "/#{artefact.slug}.json"
  
    assert_equal 200, last_response.status
    refute JSON.parse(last_response.body)["details"].has_key?('overview')
  end
  
  it "should return an empty list when there are no tags" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
  
    get "/#{artefact.slug}.json"
  
    assert_equal 200, last_response.status
    assert_equal [], JSON.parse(last_response.body)["tags"]
  end
  
  it "should list section information" do
    sections = [
      ["crime-and-justice", "Crime and justice"],
      ["crime-and-justice/batman", "Batman"]
    ]
    sections.each do |tag_id, title|
      FactoryGirl.create(:tag, tag_id: tag_id, title: title, tag_type: "section")
    end
    artefact = FactoryGirl.create(:my_non_publisher_artefact,
        sections: sections.map { |slug, title| slug },
        state: 'live')
  
    get "/#{artefact.slug}.json"
  
    assert_equal 200, last_response.status
    parsed_artefact = JSON.parse(last_response.body)
    
    parsed_artefact["tags"].reject! { |h| h["title"] == "ODI" }
    
    assert_equal 2, parsed_artefact["tags"].length
  
    # Note that this will check the ordering too
    sections.zip(parsed_artefact["tags"]).each do |section, tag_info|
      assert section.include?(tag_info["title"])
      tag_path = "/tags/sections/#{CGI.escape(section[0])}.json"
      assert_equal tag_path, URI.parse(tag_info["id"]).path
      assert_equal nil, tag_info["web_url"]
      assert_equal "section", tag_info["details"]["type"]
      # Temporary hack until the browse pages are rebuilt
      expected_section_slug = section[0]
      assert_equal "#{public_web_url}/browse/#{expected_section_slug}", tag_info["content_with_tag"]["web_url"]
    end
  end
  
  it "should set the format field at the top-level from the artefact" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
    get "/#{artefact.slug}.json"
  
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal 'smart-answer', response["format"]
  end
  
  it "should set the language field in the details node of the artefact" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
    get "/#{artefact.slug}.json"
  
    assert_equal 200, last_response.status
    response = JSON.parse(last_response.body)
    assert_equal 'en', response["details"]["language"]
  end
  
  describe "updated timestamp" do
  
    before do
      @older_timestamp = DateTime.ordinal(2013, 1, 1, 12, 00)
      @newer_timestamp = DateTime.ordinal(2013, 2, 2, 2, 22)
    end
  
    it "should set the updated_at field at the top-level from the artefact if there's no edition" do
      artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
      artefact.update_attribute(:updated_at, @newer_timestamp)
      get "/#{artefact.slug}.json"
  
      assert_equal 200, last_response.status
      response = JSON.parse(last_response.body)
      assert_equal @newer_timestamp.iso8601, response["updated_at"]
    end
  
    it "should set the updated_at field from the artefact if it's most recently updated" do
      artefact = FactoryGirl.create(:my_artefact, state: 'live')
      artefact.update_attribute(:updated_at, @newer_timestamp)
      edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')
      edition.update_attribute(:updated_at, @older_timestamp)
      get "/#{artefact.slug}.json"
  
      assert_equal 200, last_response.status
      response = JSON.parse(last_response.body)
      assert_equal @newer_timestamp.iso8601, response["updated_at"]
    end
  
    it "should set the updated_at field from the edition if it's most recently updated" do
      artefact = FactoryGirl.create(:my_artefact, state: 'live')
      artefact.update_attribute(:updated_at, @older_timestamp)
      edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')
      edition.update_attribute(:updated_at, @newer_timestamp)
      get "/#{artefact.slug}.json"
  
      assert_equal 200, last_response.status
      response = JSON.parse(last_response.body)
      assert_equal @newer_timestamp.iso8601, response["updated_at"]
    end
  end
  
  describe "publisher artefacts" do
  
    it "should return 404 if artefact is publication but never published" do
      edition = FactoryGirl.create(:edition)
  
      get "/#{edition.artefact.slug}.json"
  
      assert last_response.not_found?
      assert_status_field "not found", last_response
    end
  
    it "should return 410 if artefact is publication but only archived" do
      artefact = FactoryGirl.create(:my_artefact, state: 'live')
      edition = FactoryGirl.create(:edition, state: 'archived', panopticon_id: artefact.id)
  
      get "/#{edition.artefact.slug}.json"
  
      assert_equal 410, last_response.status
      assert_status_field "gone", last_response
    end
  
    it "gets the published edition if a previous archived edition exists" do
      artefact = FactoryGirl.create(:my_artefact, state: 'live')
      edition = FactoryGirl.create(:edition, state: 'archived', panopticon_id: artefact.id)
      FactoryGirl.create(:edition, state: 'published', panopticon_id: artefact.id)
  
      get "/#{edition.artefact.slug}.json"
  
      assert last_response.ok?
    end
  
    it "should set a future Expires header" do
      artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
  
      point_in_time = Time.now
      Timecop.freeze(point_in_time) do
        get "/#{artefact.slug}.json"
      end
      fifteen_minutes_from_now = point_in_time + 15.minutes
      assert_equal fifteen_minutes_from_now.httpdate, last_response.headers["Expires"]
    end
  
    describe "accessing unpublished editions" do
      before do
        @artefact = FactoryGirl.create(:my_artefact, state: 'live')
        @published = FactoryGirl.create(:edition, panopticon_id: @artefact.id, body: '# Published edition', state: 'published', version_number: 1)
        @draft     = FactoryGirl.create(:edition, panopticon_id: @artefact.id, body: '# Draft edition',     state: 'draft',     version_number: 2)
      end
  
      it "should return 401 if using edition parameter, not authenticated" do
        get "/#{@artefact.slug}.json?edition=anything"
        assert_equal 401, last_response.status
        assert_status_field "unauthorised", last_response
        assert_status_message "Edition parameter requires authentication", last_response
      end
  
      it "should return 403 if using edition parameter, authenticated but lacking permission" do
        Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
        Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => []))
        get "/#{@artefact.slug}.json?edition=2", {}, bearer_token_for_user_without_permission
        assert_equal 403, last_response.status
        assert_status_field "forbidden", last_response
        assert_status_message "You must be authorized to use the edition parameter", last_response
      end
  
      describe "user has permission" do
        it "should return draft data if using edition parameter, edition is draft" do
          Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
          Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => ["access_unpublished"]))
  
          get "/#{@artefact.slug}.json?edition=2", {}, bearer_token_for_user_with_permission
          assert_equal 200, last_response.status
          parsed_response = JSON.parse(last_response.body)
          assert_match(/Draft edition/, parsed_response["details"]["body"])
        end
  
        it "should return draft data if using edition parameter, edition is draft and artefact is draft" do
          Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
          Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => ["access_unpublished"]))
  
          @artefact = FactoryGirl.create(:my_artefact, state: 'draft')
          @published = FactoryGirl.create(:edition, panopticon_id: @artefact.id, state: 'draft', version_number: 1)
  
          get "/#{@artefact.slug}.json?edition=1", {}, bearer_token_for_user_with_permission
          assert_equal 200, last_response.status
          JSON.parse(last_response.body)
        end
  
        it "should 404 if a non-existent edition is requested" do
          Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
          Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => ["access_unpublished"]))
  
          get "/#{@artefact.slug}.json?edition=3", {}, bearer_token_for_user_with_permission
          assert_equal 404, last_response.status
        end
  
        it "should set an Expires header to the current time to prevent caching" do
          Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
          Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => ["access_unpublished"]))
  
          point_in_time = Time.now
          Timecop.freeze(point_in_time) do
            get "/#{@artefact.slug}.json?edition=2", {}, bearer_token_for_user_with_permission
          end
          assert_equal point_in_time.httpdate, last_response.headers["Expires"]
        end
      end
    end
  
    it "should return publication data if published" do
      artefact = FactoryGirl.create(:my_artefact, business_proposition: true, need_id: 1234, state: 'live')
      edition = FactoryGirl.create(:edition, slug: artefact.slug, panopticon_id: artefact.id, body: '# Important information', state: 'published')
  
      get "/#{artefact.slug}.json"
      parsed_response = JSON.parse(last_response.body)
  
      assert_equal 200, last_response.status
  
      assert_equal "http://example.org/#{artefact.slug}.json", parsed_response["id"]
      assert_equal "#{public_web_url}/#{artefact.slug}", parsed_response["web_url"]
      assert_equal "<h1>Important information</h1>\n", parsed_response["details"]["body"]
      assert_equal "1234", parsed_response["details"]["need_id"]
      assert_equal edition.updated_at.iso8601, parsed_response["updated_at"]
      # Temporarily included for legacy GA support. Will be replaced with "proposition" Tags
      assert_equal true, parsed_response["details"]["business_proposition"]
    end
  
    describe "processing content" do
      it "should convert artefact body and part bodies to html" do
        artefact = FactoryGirl.create(:my_artefact, slug: "annoying", state: 'live')
        FactoryGirl.create(:guide_edition,
            panopticon_id: artefact.id,
            parts: [
              Part.new(title: "Part One", body: "## Header 2", slug: "part-one")
            ],
            state: 'published')
  
        get "/#{artefact.slug}.json"
  
        parsed_response = JSON.parse(last_response.body)
        assert_equal 200, last_response.status
        assert_equal "<h2>Header 2</h2>\n", parsed_response["details"]["parts"][0]["body"]
      end
  
      it "should return govspeak in artefact body and part bodies if requested" do
        artefact = FactoryGirl.create(:my_artefact, slug: "annoying", state: 'live')
        FactoryGirl.create(:guide_edition,
            panopticon_id: artefact.id,
            parts: [
              Part.new(title: "Part One", body: "## Header 2", slug: "part-one")
            ],
            state: 'published')
  
        get "/#{artefact.slug}.json?content_format=govspeak"
  
        parsed_response = JSON.parse(last_response.body)
        assert_equal 200, last_response.status
        assert_equal "## Header 2", parsed_response["details"]["parts"][0]["body"]
      end
  
      describe "interpolating fact values" do
        it "should interploate fact values from the fact cave into the bodies" do
          skip("fact cave is a coupled api that is not used and a pain")
          fact_cave_has_a_fact('vat-rate', '20')
  
          artefact = FactoryGirl.create(:my_artefact, slug: "vat", state: 'live')
          FactoryGirl.create(:guide_edition,
              panopticon_id: artefact.id,
              parts: [
                Part.new(title: "Part One", body: "##The current VAT rate is [fact:vat-rate]%", slug: "part-one")
              ],
              state: 'published')
  
          get "/#{artefact.slug}.json"
  
          parsed_response = JSON.parse(last_response.body)
          assert_equal 200, last_response.status
          assert_equal "<h2>The current VAT rate is 20%</h2>", parsed_response["details"]["parts"][0]["body"].strip
        end
  
        it "should still interpolate fact values when govspeak requested" do
          skip("fact cave is a coupled api that is not used and a pain")
          fact_cave_has_a_fact('vat-rate', '20')
          artefact = FactoryGirl.create(:my_artefact, slug: "vat", state: 'live')
          FactoryGirl.create(:guide_edition,
              panopticon_id: artefact.id,
              parts: [
                Part.new(title: "Part One", body: "##The current VAT rate is [fact:vat-rate]%", slug: "part-one")
              ],
              state: 'published')
  
          get "/#{artefact.slug}.json?content_format=govspeak"
  
          parsed_response = JSON.parse(last_response.body)
          assert_equal 200, last_response.status
          assert_equal "##The current VAT rate is 20%", parsed_response["details"]["parts"][0]["body"]
        end
  
        it "should use a blank value if the fact cave 404's for a fact" do
          skip("fact cave is a coupled api that is not used and a pain")
          fact_cave_does_not_have_a_fact('vat-rate')
  
          artefact = FactoryGirl.create(:my_artefact, slug: "vat", state: 'live')
          FactoryGirl.create(:guide_edition,
              panopticon_id: artefact.id,
              parts: [
                Part.new(title: "Part One", body: "##The current VAT rate is [fact:vat-rate]%", slug: "part-one")
              ],
              state: 'published')
  
          get "/#{artefact.slug}.json"
  
          parsed_response = JSON.parse(last_response.body)
          assert_equal 200, last_response.status
          assert_equal "<h2>The current VAT rate is %</h2>", parsed_response["details"]["parts"][0]["body"].strip
        end
      end
    end
  
    it "should return parts in the correct order" do
      artefact = FactoryGirl.create(:my_artefact, state: 'live')
      FactoryGirl.create(:guide_edition,
        slug: artefact.slug, 
        panopticon_id: artefact.id,
        parts: [
          Part.new(title: "Part Two", order: 2, body: "## Header 3", slug: "part-two"),
          Part.new(title: "Part One", order: 1, body: "## Header 2", slug: "part-one")
        ],
        state: 'published')
  
      get "/#{artefact.slug}.json"
  
      parsed_response = JSON.parse(last_response.body)
      assert_equal 200, last_response.status
      expected_first_part = {
        "web_url" => "#{public_web_url}/#{artefact.slug}/part-one",
        "slug" => "part-one",
        "order" => 1,
        "title" => "Part One",
        "body" => "<h2>Header 2</h2>\n"
      }
      assert_equal expected_first_part, parsed_response["details"]["parts"][0]
    end
  end
  
  it "should include author details" do
    barry = FactoryGirl.create(:my_artefact, state: 'live', slug: 'barry-scott', name: "Barry Scott", kind: "person", person: ['writers'])
    FactoryGirl.create(:person_edition,      
      title: barry.name,
      slug: barry.slug, 
      panopticon_id: barry.id,
      state: 'published')
  
    artefact = FactoryGirl.create(:my_artefact, state: 'live', author: 'barry-scott')
    FactoryGirl.create(:guide_edition,
      slug: artefact.slug, 
      panopticon_id: artefact.id,
      state: 'published')
  
    get "/#{artefact.slug}.json"
    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal 'Barry Scott', parsed_response["author"]["name"]
    assert_equal 'barry-scott', parsed_response["author"]["slug"]
    assert parsed_response["author"]["tag_ids"].include?('writers')
  end
  
  it "should include node details" do
    node = FactoryGirl.create(:my_artefact, state: 'live', slug: 'westward-ho', name: "Westward Ho!", kind: "node")
    FactoryGirl.create(:node_edition,      
      title: node.name,
      slug: node.slug, 
      panopticon_id: node.id,
      level: "comms",
      beta: false,
      state: 'published')
    node = FactoryGirl.create(:my_artefact, state: 'live', slug: 'crinkly-bottom', name: "Crinkly Bottom", kind: "node")
    FactoryGirl.create(:node_edition,      
      title: node.name,
      slug: node.slug, 
      panopticon_id: node.id,
      level: "city",
      beta: true,
      state: 'published')
  
  
    artefact = FactoryGirl.create(:my_artefact, state: 'live', node: ['westward-ho', 'crinkly-bottom'])
    FactoryGirl.create(:guide_edition,
      slug: artefact.slug, 
      panopticon_id: artefact.id,
      state: 'published')
  
    get "/#{artefact.slug}.json"

    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal 'Westward Ho!', parsed_response["nodes"][0]["name"]
    assert_equal 'westward-ho', parsed_response["nodes"][0]["slug"]
    assert_equal 'comms', parsed_response["nodes"][0]["level"]
    assert_equal false, parsed_response["nodes"][0]["beta"]
    assert_equal 'Crinkly Bottom', parsed_response["nodes"][1]["name"]
    assert_equal 'crinkly-bottom', parsed_response["nodes"][1]["slug"]
    assert_equal 'city', parsed_response["nodes"][1]["level"]
    assert_equal true, parsed_response["nodes"][1]["beta"]
  end

  it "should return an empty list when there are no nodes" do
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live')
  
    get "/#{artefact.slug}.json"
  
    assert_equal 200, last_response.status
    assert_equal [], JSON.parse(last_response.body)["nodes"]
  end

  
  it "should include organization details" do
    FactoryGirl.create(:tag, tag_id: 'start-up', title: 'Start Up', tag_type: "organization")
    org = FactoryGirl.create(:my_artefact, state: 'live', slug: 'mom-corp', name: "Mom Corp.", kind: "organization", organization: ["start-up"])
    FactoryGirl.create(:organization_edition,      
      title: org.name,
      slug: org.slug, 
      panopticon_id: org.id,
      state: 'published')
    org = FactoryGirl.create(:my_artefact, state: 'live', slug: 'planet-express', name: "Planet Express", kind: "organization", organization: ["start-up"])
    FactoryGirl.create(:organization_edition,      
      title: org.name,
      slug: org.slug, 
      panopticon_id: org.id,
      state: 'published')
  
  
    artefact = FactoryGirl.create(:my_artefact, state: 'live', organization_name: ['mom-corp', 'planet-express'])
    FactoryGirl.create(:guide_edition,
      slug: artefact.slug, 
      panopticon_id: artefact.id,
      state: 'published')
  
    get "/#{artefact.slug}.json"
  
    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal 'Mom Corp.', parsed_response["organizations"][0]["name"]
    assert_equal 'mom-corp', parsed_response["organizations"][0]["slug"]
    assert_equal 'Planet Express', parsed_response["organizations"][1]["name"]
    assert_equal 'planet-express', parsed_response["organizations"][1]["slug"]
  end
  
  it "should return correct urls for an edition type" do
    artefact = FactoryGirl.create(:my_artefact, state: 'live')
    FactoryGirl.create(:job_edition,
      slug: artefact.slug, 
      panopticon_id: artefact.id,
      state: 'published')
      
    get "/#{artefact.slug}.json"
    
    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal "https://www.gov.uk/jobs/#{artefact.slug}", parsed_response['web_url']
  end
  
  it "should return correct urls for an edition tag" do
    FactoryGirl.create(:tag, :tag_id => "team", :tag_type => 'person', :title => "Team Member")
    FactoryGirl.create(:tag, :tag_id => "technical", :tag_type => 'team', :title => "Tech Team")
    artefact = FactoryGirl.create(:my_artefact, state: 'live', person: ['team'], team: ['technical'])
    n = PersonEdition.create(:title         => "Person", 
                             :panopticon_id => artefact.id,
                             :slug          => artefact.slug,
                             :state         => "published")
        
    get "/#{artefact.slug}.json"
    
    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal "https://www.gov.uk/team/#{artefact.slug}", parsed_response['web_url']
  end

  it "should 404 if the role requested does not match the artefact's role" do
    FactoryGirl.create(:tag, :tag_id => "odi", :tag_type => 'role', :title => "ODI")
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live', roles: ['odi'])
    
    get "/#{artefact.slug}.json?role=bar"
    assert_equal 404, last_response.status
  end
  
  it "should return 200 if the role requested matches the artefact's role" do
    FactoryGirl.create(:tag, :tag_id => "bar", :tag_type => 'role', :title => "bar")
    artefact = FactoryGirl.create(:my_non_publisher_artefact, state: 'live', roles: ['bar'])
    
    get "/#{artefact.slug}.json?role=bar"
    assert_equal 200, last_response.status
  end

end
