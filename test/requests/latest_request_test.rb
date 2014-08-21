require 'test_helper'

class LatestRequestTest < GovUkContentApiTest
  
  describe "latest.json" do
    before :each do
      tag = FactoryGirl.create(:tag, tag_id: "news", tag_type: "article")
      5.times do |n|
        artefact = FactoryGirl.create(:my_artefact, name: "This was created #{n} days ago", owning_app: "publisher", article: ['news'], state: 'live', kind: "Article", created_at: n.days.ago, slug: "#{n}-days-ago")
        edition = ArticleEdition.create(panopticon_id: artefact.id, title: artefact.name, content: "A really long description\n\nWith line breaks.", state: "published", slug: artefact.slug)
      end
    end
    
    it "should load the latest article by tag" do      
      get "/latest.json?tag=news"
      assert last_response.ok?
      assert_equal "This was created 0 days ago", JSON.parse(last_response.body)['title']
    end
    
    it "should return 404 if the tag is unknown" do
      get "/latest.json?tag=fake"
      assert last_response.not_found?
    end

    it "should load the latest article by type" do      
      get "/latest.json?type=article"
      assert last_response.ok?
      assert_equal "This was created 0 days ago", JSON.parse(last_response.body)['title']
    end   
    
    it "should return 404 if the type is unknown" do
      get "/latest.json?type=fake"
      assert last_response.not_found?
    end 
  end

  describe "latest.json with roles" do

    before :all do
      FactoryGirl.create(:tag, tag_id: "odi",  tag_type: 'role', title: "odi")
      FactoryGirl.create(:tag, tag_id: "dapaas",  tag_type: 'role', title: "dapaas")
      FactoryGirl.create(:tag, tag_id: "blog", tag_type: "article")
      artefact = FactoryGirl.create(:my_artefact,
        name: "ODI",
        owning_app: "publisher",
        article: ['blog'],
        # roles: ['odi'],
        state: 'live',
        kind: "Article",
        slug: "odi",
        created_at: 10.minutes.ago)
      ArticleEdition.create(panopticon_id: artefact.id, title: artefact.name, content: "", state: "published", slug: artefact.slug)
      artefact = FactoryGirl.create(:my_artefact,
        name: "DaPaaS",
        owning_app: "publisher",
        article: ['blog'],
        roles: ['dapaas'],
        state: 'live',
        kind: "Article",
        slug: "dapaas")
      ArticleEdition.create(panopticon_id: artefact.id, title: artefact.name, content: "", state: "published", slug: artefact.slug)
    end

    it "should show the latest item for the default role if role isn't specified" do
      get "/latest.json?tag=blog"
      assert last_response.ok?
      assert_equal "ODI", JSON.parse(last_response.body)['title']
    end

    it "should show the latest item for the specified role if that is the latest one" do
      get "/latest.json?tag=blog&role=dapaas"
      assert last_response.ok?
      assert_equal "DaPaaS", JSON.parse(last_response.body)['title']
    end

    it "should show the latest item for the specified role if there is a newer one in another role" do
      get "/latest.json?tag=blog&role=odi"
      assert last_response.ok?
      assert_equal "ODI", JSON.parse(last_response.body)['title']
    end

  end

end
