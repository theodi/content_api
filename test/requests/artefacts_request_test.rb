require_relative '../test_helper'

class ArtefactsRequestTest < GovUkContentApiTest

  it "should return empty array with no artefacts" do
    get "/artefacts.json"

    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)
    assert_equal 0, parsed_response["total"]
    assert_equal [], parsed_response["results"]
  end

  it "should return all artefacts" do
    FactoryGirl.create(:my_artefact, :name => "Alpha", :state => 'live')
    FactoryGirl.create(:my_artefact, :name => "Bravo", :state => 'live')
    FactoryGirl.create(:my_artefact, :name => "Charlie", :state => 'live')

    get "/artefacts.json"

    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 3, parsed_response["total"]
    assert_equal %w(Alpha Bravo Charlie), parsed_response["results"].map {|a| a["title"]}.sort
  end

  it "should only include live artefacts" do
    FactoryGirl.create(:my_artefact, :name => "Alpha", :state => 'draft')
    FactoryGirl.create(:my_artefact, :name => "Bravo", :state => 'live')
    FactoryGirl.create(:my_artefact, :name => "Charlie", :state => 'archived')

    get "/artefacts.json"

    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["total"]
    assert_equal %w(Bravo), parsed_response["results"].map {|a| a["title"]}.sort
  end

  it "should only include minimal information for each artefact" do
    FactoryGirl.create(:my_artefact, :slug => "bravo", :name => "Bravo", :state => 'live', :kind => "guide")

    get "/artefacts.json"

    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["total"]

    result = parsed_response["results"].first

    assert_equal %w(id web_url title format).sort, result.keys.sort
    assert_equal "Bravo", result["title"]
    assert_equal "guide", result["format"]
    assert_equal "#{public_web_url}/bravo", result["web_url"]
    assert_equal "http://example.org/bravo.json", result["id"]
  end
  
  it "should only return those artefacts with a particular node" do
    FactoryGirl.create(:my_artefact, :slug => "bravo", :name => "Bravo", :state => 'live', :kind => "guide", :node => ["westward-ho!", "john-o-groats"])
    FactoryGirl.create(:my_artefact, :slug => "alpha", :name => "Alpha", :state => 'live', :kind => "guide")
    
    get "/artefacts.json?node=westward-ho!"
    
    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["total"]
        
    assert_equal "Bravo", parsed_response["results"][0]["title"]
  end
  
  it "should only return those artefacts with a particular author" do
    FactoryGirl.create(:my_artefact, :slug => "bravo", :name => "Bravo", :state => 'live', :kind => "guide", :author => "barry-scott")
    FactoryGirl.create(:my_artefact, :slug => "alpha", :name => "Alpha", :state => 'live', :kind => "guide", :author => "ian-mac-shane")
    
    get "/artefacts.json?author=barry-scott"
    
    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["total"]
    
    assert_equal "Bravo", parsed_response["results"][0]["title"]
  end
  
  it "should only return those artefacts with a particular organization_name" do
    FactoryGirl.create(:my_artefact, :slug => "bravo", :name => "Bravo", :state => 'live', :kind => "guide", :organization_name => ["mom-corp", "planet-express"])
    FactoryGirl.create(:my_artefact, :slug => "alpha", :name => "Alpha", :state => 'live', :kind => "guide", :organization_name => ["wayne-enterprises"])
    
    get "/artefacts.json?organization_name=mom-corp"
    
    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["total"]
    
    assert_equal "Bravo", parsed_response["results"][0]["title"]
  end
  
  it "should only return those artefacts with a particular role" do
    FactoryGirl.create(:tag, :tag_id => "foo", :tag_type => 'role', :title => "foo")
    FactoryGirl.create(:tag, :tag_id => "bar", :tag_type => 'role', :title => "bar")
    
    FactoryGirl.create(:my_artefact, :slug => "bravo", :name => "Bravo", :state => 'live', :kind => "guide", :roles => ['foo'])
    FactoryGirl.create(:my_artefact, :slug => "alpha", :name => "Alpha", :state => 'live', :kind => "guide", :roles => ['bar'])
    
    get "/artefacts.json?role=foo"
    
    assert_equal 200, last_response.status
    assert_status_field "ok", last_response

    parsed_response = JSON.parse(last_response.body)

    assert_equal 1, parsed_response["total"]
    
    assert_equal "Bravo", parsed_response["results"][0]["title"]
  end

  describe "with pagination" do
    def setup
      # Stub this out to avoid configuration changes breaking tests
      app.stubs(:pagination).returns(true)
      Artefact.stubs(:default_per_page).returns(10)
    end

    it "should paginate when there are enough artefacts" do
      FactoryGirl.create(:tag, :tag_id => "odi", :tag_type => 'role', :title => "odi")
      FactoryGirl.create_list(:my_artefact, 25, :state => "live")

      get "/artefacts.json"

      assert last_response.ok?
      parsed_response = JSON.parse(last_response.body)
      assert_equal 10, parsed_response["results"].count
      assert_has_values parsed_response, "total" => 25, "current_page" => 1,
                                         "pages" => 3

      assert_link "next",  "http://example.org/artefacts.json?page=2"
      refute_link "previous"
    end

    it "should display subsequent pages" do
      FactoryGirl.create(:tag, :tag_id => "odi", :tag_type => 'role', :title => "odi")
      FactoryGirl.create_list(:my_artefact, 25, :state => "live")

      get "/artefacts.json?page=3"

      assert last_response.ok?
      parsed_response = JSON.parse(last_response.body)
      assert_equal 5, parsed_response["results"].count
      assert_has_values parsed_response, "total" => 25, "current_page" => 3,
                                         "pages" => 3

      assert_link "previous",  "http://example.org/artefacts.json?page=2"
      refute_link "next"
    end
  end

  describe "without pagination" do
    def setup
      app.stubs(:pagination).returns(false)
    end

    it "should display large numbers of artefacts" do
      FactoryGirl.create(:tag, :tag_id => "odi", :tag_type => 'role', :title => "odi")
      FactoryGirl.create_list(:my_artefact, 25, :state => "live")

      get "/artefacts.json"

      assert last_response.ok?
      parsed_response = JSON.parse(last_response.body)
      assert_equal 25, parsed_response["results"].count
      assert_has_values parsed_response, "total" => 25, "current_page" => 1,
                                         "pages" => 1
      refute_link "next"
      refute_link "previous"
    end
  end
end
