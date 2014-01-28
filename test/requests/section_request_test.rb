require 'test_helper'
require 'uri'
require 'gds_api/test_helpers/asset_manager'

class SectionRequestTest < GovUkContentApiTest
  include GdsApi::TestHelpers::AssetManager
  
  describe "section.json" do
    before :each do
      asset_manager_has_an_asset("512c9019686c82191d000001", {
        "id" => "http://asset-manager.#{ENV["GOVUK_APP_DOMAIN"]}/assets/512c9019686c82191d000001",
        "name" => "darth-on-a-cat.jpg",
        "content_type" => "image/jpeg",
        "file_url" => "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat.jpg",
        "state" => "clean",
      })
    
      @section = Section.create(:tag_id => "foo", :title => "Foo Bar", :link => "http://www.example.com", :description => "This is a description", :hero_image_id => "512c9019686c82191d000001")
    end
  
    it "should load the section details" do
      get "/section.json?id=foo"
      
      assert last_response.ok?
      
      json = JSON.parse(last_response.body)
      
      assert_equal "Foo Bar", json['title']
      assert_equal "http://www.example.com", json['link']
      assert_equal "This is a description", json['description']
      assert_equal "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat.jpg", json['hero']
    end
    
    it "should not error if a hero image is not present" do
      section = Section.create(:tag_id => "bar", :title => "Foo Bar", :link => "http://www.example.com", :description => "This is a description")
      
      get "/section.json?id=bar"
      
      assert last_response.ok?
      
      json = JSON.parse(last_response.body)
            
      assert_equal nil, json['hero']      
    end
    
    it "should load modules" do
      image = SectionModule.create(:title => "This is an image", :type => "Image", :link => "http://www.example.com", :image_id => "512c9019686c82191d000001")
      frame = SectionModule.create(:title => "This is a frame", :type => "Frame", :frame => "news")
      text = SectionModule.create(:title => "This is a text module", :type => "Text", :text => "Here is some text", :link => "http://www.example.com", :colour => "2")
      
      @section.modules = [text.id, image.id, frame.id]
      @section.save
      
      get "/section.json?id=foo"
      
      assert last_response.ok?
      
      json = JSON.parse(last_response.body)
      
      assert_equal "This is a text module", json['modules'][0]['title']
      assert_equal "Text", json['modules'][0]['type']
      assert_equal "Here is some text", json['modules'][0]['text']
      assert_equal "http://www.example.com", json['modules'][0]['link']
      assert_equal "2", json['modules'][0]['colour']
      
      assert_equal "This is an image", json['modules'][1]['title']
      assert_equal "Image", json['modules'][1]['type']
      assert_equal "http://www.example.com", json['modules'][1]['link']
      assert_equal "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat.jpg", json['modules'][1]['image']
      
      assert_equal "This is a frame", json['modules'][2]['title']
      assert_equal "Frame", json['modules'][2]['type']
      assert_equal "news", json['modules'][2]['frame']
    end
  end
  
end