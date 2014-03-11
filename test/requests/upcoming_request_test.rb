require 'test_helper'

class UpcomingRequestTest < GovUkContentApiTest
  
  describe "latest.json" do
    
    describe "With 5 upcoming events" do
      
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

      it "should include event type in details" do   
        get "/upcoming.json?type=event&order_by=start_date"
        assert_equal "lunchtime-lecture", JSON.parse(last_response.body)['details']['event_type']
      end
      
    end
    
    describe "with roles" do
      before :each do
        FactoryGirl.create(:tag, tag_id: 'lunchtime-lecture', title: "Lunchtime Lecture", tag_type: "event")
        FactoryGirl.create(:tag, :tag_id => "not_odi", :tag_type => 'role', :title => "Not ODI")
        FactoryGirl.create(:tag, :tag_id => "odi", :tag_type => 'role', :title => "ODI")

        non_odi = FactoryGirl.create(:my_artefact, name: "A non-ODI event", owning_app: "publisher", state: 'live', kind: "Event", slug: "non-odi", event: ["lunchtime-lecture"], roles: ['not_odi'])
        odi = FactoryGirl.create(:my_artefact, name: "An ODI event", owning_app: "publisher", state: 'live', kind: "Event", slug: "odi", event: ["lunchtime-lecture"], roles: ['odi'])

        EventEdition.create(panopticon_id: non_odi.id, title: non_odi.name, start_date: 1.days.from_now.to_time.utc, state: "published", slug: non_odi.slug)
        EventEdition.create(panopticon_id: odi.id, title: odi.name, start_date: 2.days.from_now.to_time.utc, state: "published", slug: odi.slug)
      end
    
      it "should return an event with the default role" do
        get "/upcoming.json?type=event&order_by=start_date"
      
        assert_equal "An ODI event", JSON.parse(last_response.body)['title']
      end
    
      it "should return an event with the specified role" do
        get "/upcoming.json?type=event&order_by=start_date&role=not_odi"
      
        assert_equal "A non-ODI event", JSON.parse(last_response.body)['title']
      end
    
    end 
    
  end
  
end