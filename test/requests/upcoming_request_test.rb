require 'test_helper'

class UpcomingRequestTest < GovUkContentApiTest
  
  describe "latest.json" do
    before :each do
      5.times do |n|
        artefact = FactoryGirl.create(:artefact, name: "This was created #{n} days ago", owning_app: "publisher", state: 'live', kind: "Event", slug: "#{n}-days-from-now")
        edition = EventEdition.create(panopticon_id: artefact.id, title: artefact.name, start_date: n.days.from_now.to_time.utc, state: "published", slug: artefact.slug)
      end
    end
    
    it "should load the latest event ordered by date" do   
      get "/upcoming.json?type=event&order_by=start_date"
      assert last_response.redirect?
      assert_equal "http://example.org/0-days-from-now.json", last_response.location
    end
    
    it "should return 404 if the type is not known" do
      get "/upcoming.json?type=fake&order_by=start_date"
      assert last_response.not_found?
    end
    
    it "should return 404 if the type doesn't respond to the order_by param" do
      get "/upcoming.json?type=event&order_by=foo"
      assert last_response.not_found?
    end
  end  
  
end