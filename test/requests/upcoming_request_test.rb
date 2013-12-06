require 'test_helper'

class UpcomingRequestTest < GovUkContentApiTest
  
  describe "latest.json" do
    before :each do
      5.times do |n|
        tag = FactoryGirl.create(:tag, tag_id: 'lunchtime-lecture', title: "Lunchtime Lecture", tag_type: "event")
        artefact = FactoryGirl.create(:my_artefact, name: "An event #{n} days from now", owning_app: "publisher", state: 'live', kind: "Event", slug: "#{n}-days-from-now", event: ["lunchtime-lecture"])
        edition = EventEdition.create(panopticon_id: artefact.id, title: artefact.name, start_date: n.days.from_now.to_time.utc, state: "published", slug: artefact.slug)
      end
    end
    
    it "should load the latest event ordered by date" do   
      get "/upcoming.json?type=event&order_by=start_date"
      assert last_response.ok?
      assert_equal "An event 0 days from now", JSON.parse(last_response.body)['title']
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