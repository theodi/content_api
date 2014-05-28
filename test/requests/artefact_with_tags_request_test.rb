require_relative '../test_helper'
require "gds_api/test_helpers/asset_manager"

class ArtefactWithTagsRequestTest < GovUkContentApiTest
  include GdsApi::TestHelpers::AssetManager

  describe "handling requests with a tag= parameter" do
    it "should return 404 if no tag is provided" do
      Tag.expects(:where).never

      ["/with_tag.json", "/with_tag.json?tag="].each do |url|
        get url
        assert last_response.not_found?
        assert_status_field "not found", last_response
      end
    end

    it "should return 404 if tag not found" do
      Tag.expects(:where).with(tag_id: 'farmers').returns([])

      get "/with_tag.json?tag=farmers"

      assert last_response.not_found?
      assert_status_field "not found", last_response
    end

    it "should return 404 if multiple tags found" do
      tags = %w(section keyword).map { |tag_type|
        Tag.new(tag_id: "ambiguity", title: "Ambiguity", tag_type: tag_type)
      }
      Tag.expects(:where).with(tag_id: "ambiguity").returns(tags)

      get "/with_tag.json?tag=ambiguity"

      assert last_response.not_found?
      assert_status_field "not found", last_response
    end

    it "should redirect to the typed URL with zero results" do
      t = Tag.new(tag_id: 'farmers', title: 'Farmers', tag_type: 'keyword')
      Tag.stubs(:where).with(tag_id: 'farmers').returns([t])

      get "/with_tag.json?tag=farmers"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?keyword=farmers",
        last_response.location
      )
    end

    it "should redirect to a content type if one is found" do
      get "/with_tag.json?tag=job"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?type=job",
        last_response.location
      )
    end

    it "should redirect to the typed URL with multiple results" do
      farmers = FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'keyword')
      FactoryGirl.create(:my_artefact, owning_app: "smart-answers", keywords: ['farmers'], state: 'live')

      get "/with_tag.json?tag=farmers"
      assert_equal(
        "http://example.org/with_tag.json?keyword=farmers",
        last_response.location
      )
    end

    it "should preserve the specified sort order when redirecting" do
      batman = FactoryGirl.create(:tag, tag_id: 'batman', title: 'Batman', tag_type: 'section')
      get "/with_tag.json?tag=batman&sort=bobbles"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?section=batman&sort=bobbles",
        last_response.location
      )
    end

    it "should preserve the specified node when redirecting" do
      batman = FactoryGirl.create(:tag, tag_id: 'batman', title: 'Batman', tag_type: 'section')
      get "/with_tag.json?tag=batman&node=thing"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?section=batman&node=thing",
        last_response.location
      )
    end

    it "should preserve the specified author when redirecting" do
      batman = FactoryGirl.create(:tag, tag_id: 'batman', title: 'Batman', tag_type: 'section')
      get "/with_tag.json?tag=batman&author=bloke"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?section=batman&author=bloke",
        last_response.location
      )
    end

    it "should preserve the specified role when redirecting" do
      batman = FactoryGirl.create(:tag, tag_id: 'batman', title: 'Batman', tag_type: 'section')
      get "/with_tag.json?tag=batman&role=odi"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?section=batman&role=odi",
        last_response.location
      )
    end

    it "should preserve the specified organization_name when redirecting" do
      batman = FactoryGirl.create(:tag, tag_id: 'batman', title: 'Batman', tag_type: 'section')
      get "/with_tag.json?tag=batman&organization_name=wayne-enterprises"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?section=batman&organization_name=wayne-enterprises",
        last_response.location
      )
    end

    it "should allow filtering by multiple tags" do
      farmers = FactoryGirl.create(:tag, tag_id: 'crime', title: 'Crime', tag_type: 'section')
      business = FactoryGirl.create(:tag, tag_id: 'business', title: 'Business', tag_type: 'section')

      get "/with_tag.json?tag=crime,business"
      assert last_response.redirect?
      assert_equal(
        "http://example.org/with_tag.json?section=crime%2Cbusiness",
        last_response.location
      )
    end
  end

  describe "handling requests for typed tags" do
    describe "with a valid request" do
      before :each do
        @farmers = FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'keyword')
        @business = FactoryGirl.create(:tag, tag_id: 'business', title: 'Business', tag_type: 'section')
      end

      it "should return an array of results" do
        artefact = FactoryGirl.create(:my_artefact, owning_app: "publisher", keywords: ['farmers'], state: 'live', description: "Artefact description", kind: "Course")
        edition = ArticleEdition.create(panopticon_id: artefact.id, title: artefact.name, content: "A really long description\n\nWith line breaks.", state: "published", slug: artefact.slug)

        get "/with_tag.json?keyword=farmers"

        assert last_response.ok?
        parsed_response = JSON.parse(last_response.body)
        assert_equal 1, parsed_response["results"].count

        details = parsed_response["results"].first
        assert_equal artefact.name, details["title"]
        assert details["tag_ids"].include?('farmers')
        assert_equal "Artefact description", details["details"]["description"]
        assert_equal "A really long description", details["details"]["excerpt"]
      end

      it "should return the standard response even if zero results" do
        get "/with_tag.json?keyword=farmers"
        parsed_response = JSON.parse(last_response.body)

        assert last_response.ok?
        assert_equal 0, parsed_response["total"]
        assert_equal [], parsed_response["results"]
      end

      it "should exclude artefacts which aren't live" do
        draft    = FactoryGirl.create(:my_non_publisher_artefact, keywords: ['farmers'], state: 'draft')
        live     = FactoryGirl.create(:my_non_publisher_artefact, keywords: ['farmers'], state: 'live')
        archived = FactoryGirl.create(:my_non_publisher_artefact, keywords: ['farmers'], state: 'archived')

        get "/with_tag.json?keyword=farmers"

        assert last_response.ok?
        response = JSON.parse(last_response.body)
        assert_equal 1, response["results"].count
        assert_equal "http://example.org/#{live.slug}.json", response["results"][0]["id"]
      end

      it "should exclude unpublished publisher items" do
        artefact = FactoryGirl.create(:my_artefact, owning_app: "publisher", sections: ['business'])
        FactoryGirl.create(:edition, panopticon_id: artefact.id, state: "ready")

        get "/with_tag.json?section=business"

        assert last_response.ok?, "request failed: #{last_response.status}"
        assert_equal 0, JSON.parse(last_response.body)["results"].count
      end

      it "should only return those artefacts with a particular node" do
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', keywords: ['farmers'], state: 'live', node: ['westward-ho!', 'john-o-groats'])
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 2', keywords: ['farmers'], state: 'live')

        get "/with_tag.json?keyword=farmers&node=westward-ho!"

        assert_equal 200, last_response.status

        parsed_response = JSON.parse(last_response.body)

        assert_equal 1, parsed_response["results"].count

        assert_equal "Thing 1", parsed_response["results"][0]["title"]
      end

      it "should only return those artefacts with a particular organization_name" do
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', keywords: ['farmers'], state: 'live', organization_name: ["mom-corp", "planet-express"])
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 2', keywords: ['farmers'], state: 'live', organization_name: ["wayne-enterprises"])

        get "/with_tag.json?keyword=farmers&organization_name=mom-corp"

        assert_equal 200, last_response.status

        parsed_response = JSON.parse(last_response.body)

        assert_equal 1, parsed_response["results"].count

        assert_equal "Thing 1", parsed_response["results"][0]["title"]
      end

      it "should only return those artefacts with a particular author" do
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', keywords: ['farmers'], state: 'live', author: "barry-scott")
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 2', keywords: ['farmers'], state: 'live', author: "ian-mac-shane")

        get "/with_tag.json?keyword=farmers&author=barry-scott"

        assert_equal 200, last_response.status

        parsed_response = JSON.parse(last_response.body)

        assert_equal 1, parsed_response["results"].count

        assert_equal "Thing 1", parsed_response["results"][0]["title"]
      end

      it "should only return those artefacts with a particular role" do
        FactoryGirl.create(:tag, :tag_id => "foo", :tag_type => 'role', :title => "foo")
        FactoryGirl.create(:tag, :tag_id => "bar", :tag_type => 'role', :title => "bar")

        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', keywords: ['farmers'], state: 'live', roles: ['foo'])
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 2', keywords: ['farmers'], state: 'live', roles: ['bar'])

        get "/with_tag.json?keyword=farmers&role=foo"

        assert_equal 200, last_response.status

        parsed_response = JSON.parse(last_response.body)

        assert_equal 1, parsed_response["results"].count

        assert_equal "Thing 1", parsed_response["results"][0]["title"]
      end
    end

    describe "error handling" do
      it "should return 404 if typed tag not found" do
        Tag.expects(:by_tag_id).with("farmers", "keyword").returns(nil)

        get "/with_tag.json?keyword=farmers"

        assert last_response.not_found?
        assert_status_field "not found", last_response
      end

      it "should return a 404 if an unsupported sort order is requested" do
        batman = FactoryGirl.create(:tag, tag_id: 'batman', title: 'Batman', tag_type: 'section')
        bat = FactoryGirl.create(:my_artefact, owning_app: 'publisher', sections: ['batman'], name: 'Bat', slug: 'batman')
        bat_guide = FactoryGirl.create(:guide_edition, panopticon_id: bat.id, state: "published", slug: 'batman')
        get "/with_tag.json?section=batman&sort=bobbles"

        assert last_response.not_found?
        assert_status_field "not found", last_response
      end

      it "should allow filtering by multiple typed tags" do
        farmers = FactoryGirl.create(:tag, tag_id: 'crime', title: 'Crime', tag_type: 'section')
        business = FactoryGirl.create(:tag, tag_id: 'business', title: 'Business', tag_type: 'section')

        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', sections: ['crime'], state: 'live')
        FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 2', sections: ['business'], state: 'live')

        get "/with_tag.json?section=crime,business"

        assert_equal 200, last_response.status
        parsed_response = JSON.parse(last_response.body)

        assert_equal "All content with the 'crime,business' section", parsed_response["description"]
        assert_equal 2, parsed_response["results"].count
      end
    end
  end

  describe "handling requests for types" do

    it "should return all artefacts of that specific type" do
      5.times do |n|
        FactoryGirl.create(:my_non_publisher_artefact, kind: 'case_study', state: 'live')
      end

      get "with_tag.json?type=case_study"
      response = JSON.parse(last_response.body)
      assert last_response.ok?
      assert_equal 5, response["results"].count
    end

    it "should return successfully if a plural type is requested" do
      5.times do |n|
        FactoryGirl.create(:my_non_publisher_artefact, kind: 'job', state: 'live')
      end

      get "with_tag.json?type=jobs"
      response = JSON.parse(last_response.body)
      assert last_response.ok?
      assert_equal 5, response["results"].count
    end

    it "should return 404 if no artefacts for that type" do
      get "with_tag.json?type=article"

      assert last_response.not_found?
      assert_status_field "not found", last_response
    end

    it "should only return those artefacts with a particular role" do
      FactoryGirl.create(:tag, :tag_id => "foo", :tag_type => 'role', :title => "foo")
      FactoryGirl.create(:tag, :tag_id => "bar", :tag_type => 'role', :title => "bar")

      FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', kind: 'job', state: 'live', roles: ['foo'])
      FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 2', kind: 'job', state: 'live', roles: ['bar'])

      get "/with_tag.json?type=jobs&role=foo"

      assert_equal 200, last_response.status

      parsed_response = JSON.parse(last_response.body)

      assert_equal 1, parsed_response["results"].count

      assert_equal "Thing 1", parsed_response["results"][0]["title"]
    end

  end

  it "should include author details" do
    barry = FactoryGirl.create(:my_artefact, state: 'live', slug: 'barry-scott', name: "Barry Scott", kind: "person", person: ['writers'])
    FactoryGirl.create(:person_edition,
      title: barry.name,
      slug: barry.slug,
      panopticon_id: barry.id,
      state: 'published')

    FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'keyword')
    FactoryGirl.create(:my_non_publisher_artefact, name: 'Thing 1', keywords: ['farmers'], state: 'live', author: "barry-scott")

    get "/with_tag.json?keyword=farmers&author=barry-scott"

    assert_equal 200, last_response.status

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["results"].count
    assert_equal "Thing 1", parsed_response["results"][0]["title"]
    assert_equal 'Barry Scott', parsed_response["results"][0]["details"]["author"]["name"]
    assert_equal 'barry-scott', parsed_response["results"][0]["details"]["author"]["slug"]
    assert parsed_response["results"][0]["details"]["author"]["tag_ids"].include?('writers')
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


    FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'keyword')
    artefact = FactoryGirl.create(:my_artefact, keywords: ['farmers'], state: 'live', node: ['westward-ho', 'crinkly-bottom'])
    FactoryGirl.create(:guide_edition,
      slug: artefact.slug,
      panopticon_id: artefact.id,
      state: 'published')

    get "/with_tag.json?keyword=farmers&node=westward-ho"

    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal 'Westward Ho!', parsed_response["results"][0]["details"]["nodes"][0]["name"]
    assert_equal 'westward-ho', parsed_response["results"][0]["details"]["nodes"][0]["slug"]
    assert_equal 'comms', parsed_response["results"][0]["details"]["nodes"][0]["level"]
    assert_equal false, parsed_response["results"][0]["details"]["nodes"][0]["beta"]
    assert_equal 'Crinkly Bottom', parsed_response["results"][0]["details"]["nodes"][1]["name"]
    assert_equal 'crinkly-bottom', parsed_response["results"][0]["details"]["nodes"][1]["slug"]
    assert_equal 'city', parsed_response["results"][0]["details"]["nodes"][1]["level"]
    assert_equal true, parsed_response["results"][0]["details"]["nodes"][1]["beta"]
  end

  it "should include organization details" do
    FactoryGirl.create(:tag, tag_id: 'start-up', title: 'Start Up', tag_type: "organization")
    organization = FactoryGirl.create(:my_artefact, state: 'live', slug: 'mom-corp', name: "Mom Corp.", kind: "organization", organization: ['start-up'])
    FactoryGirl.create(:organization_edition,
      title: organization.name,
      slug: organization.slug,
      panopticon_id: organization.id,
      state: 'published')
    organization = FactoryGirl.create(:my_artefact, state: 'live', slug: 'planet-express', name: "Planet Express", kind: "organization", organization: ['start-up'])
    FactoryGirl.create(:organization_edition,
      title: organization.name,
      slug: organization.slug,
      panopticon_id: organization.id,
      state: 'published')


    FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'keyword')
    artefact = FactoryGirl.create(:my_artefact, keywords: ['farmers'], state: 'live', organization_name: ['mom-corp', 'planet-express'])
    FactoryGirl.create(:guide_edition,
      slug: artefact.slug,
      panopticon_id: artefact.id,
      state: 'published')

    get "/with_tag.json?keyword=farmers&organization_name=planet-express"

    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal 'Mom Corp.', parsed_response["results"][0]["details"]["organizations"][0]["name"]
    assert_equal 'mom-corp', parsed_response["results"][0]["details"]["organizations"][0]["slug"]
    assert_equal 'Planet Express', parsed_response["results"][0]["details"]["organizations"][1]["name"]
    assert_equal 'planet-express', parsed_response["results"][0]["details"]["organizations"][1]["slug"]
  end

  it "should show the event type for events" do
     FactoryGirl.create(:tag, tag_id: 'lunchtime-lecture', title: 'Lunchtime Lecture', tag_type: "event")
     lecture = FactoryGirl.create(:my_artefact, state: 'live', slug: 'lunchtime-lecture', name: "Lunchtime Lecture", kind: "event", event: ['lunchtime-lecture'])
     FactoryGirl.create(:event_edition,
       title: lecture.name,
       slug: lecture.slug,
       panopticon_id: lecture.id,
       state: 'published')

    get "/with_tag.json?type=event"

    parsed_response = JSON.parse(last_response.body)
    assert_equal 200, last_response.status

    assert_equal "lunchtime-lecture", parsed_response["results"][0]["details"]["event_type"]
  end

  describe "whole body" do

    before :each do
      @artefact = FactoryGirl.create(:my_non_publisher_artefact, :state => 'live')
      FactoryGirl.create(:tag, tag_id: 'news', title: 'News', tag_type: "article")
      article = FactoryGirl.create(:my_artefact, state: 'live', slug: 'here-is-some-news', name: "Here is some news", kind: "article", article: ['news'])

      @content = "Bacon ipsum dolor sit amet tongue bacon jerky, salami turducken meatloaf prosciutto andouille rump corned beef short ribs shoulder doner. Hamburger meatball ball tip, flank beef venison shoulder ham hock brisket kielbasa. Ribeye turkey pastrami sirloin chicken, pancetta capicola spare ribs pork chop. Pork belly kielbasa pork chop ground round boudin meatball pastrami spare ribs.

      Short ribs chuck leberkas pork belly frankfurter bacon doner, biltong turducken short loin. Brisket shankle tri-tip cow, turkey tongue kielbasa leberkas frankfurter. Filet mignon sirloin ground round shoulder, rump beef ribs ribeye pork belly pastrami ball tip kevin. Brisket rump salami frankfurter beef pancetta. Cow short loin landjaeger ground round kielbasa beef ribs strip steak leberkas chicken frankfurter pork belly. Bacon turducken ribeye pork chop meatball, tail hamburger doner short loin kevin boudin drumstick ham shank pancetta.

      Turkey pancetta boudin ground round leberkas brisket bresaola spare ribs turducken kevin shoulder kielbasa chuck. Pig pancetta bacon drumstick capicola ribeye prosciutto frankfurter, brisket tail. Shoulder short ribs rump tongue leberkas pork loin pastrami hamburger. Bacon pancetta short loin ground round. Hamburger ball tip turkey pork loin. Pastrami bresaola short ribs rump strip steak doner tri-tip bacon brisket frankfurter jowl hamburger leberkas."


      FactoryGirl.create(:article_edition,
        title: article.name,
        slug: article.slug,
        panopticon_id: article.id,
        content: @content,
        state: 'published')
    end

    it "should show when whole_body is set to true" do
       get "/with_tag.json?article=news&whole_body=true"

       parsed_response = JSON.parse(last_response.body)
       assert_equal 200, last_response.status
       assert_equal Govspeak::Document.new(@content, auto_ids: false).to_html, parsed_response["results"][0]["details"]["body"]
    end

    it "should not show when whole_body is not set to true" do
      get "/with_tag.json?article=news"

      parsed_response = JSON.parse(last_response.body)
      assert_equal 200, last_response.status
      assert_nil parsed_response["results"][0]["details"]["body"]
    end

  end

end
