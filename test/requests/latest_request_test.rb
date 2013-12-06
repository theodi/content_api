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
  
end