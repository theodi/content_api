require 'test_helper'

class LectureListTest < GovUkContentApiTest

  describe "lecture-list.json" do

    before :each do
      tag = FactoryGirl.create(:tag, tag_id: 'lunchtime-lecture', title: "Lunchtime Lecture", tag_type: "event")

      (1..5).each do |n|
        artefact = FactoryGirl.create(:my_artefact, name: "An event #{n} days from now", owning_app: "publisher", state: 'live', kind: "Event", slug: "#{n}-days-from-now", event: ["lunchtime-lecture"])
        edition = EventEdition.create(panopticon_id: artefact.id, title: artefact.name, start_date: n.days.from_now.to_time.utc, state: "published", slug: artefact.slug)
      end

      (1..10).each do |n|
        artefact = FactoryGirl.create(:my_artefact, name: "An event #{n} days in the past", owning_app: "publisher", state: 'live', kind: "Event", slug: "#{n}-days-ago", event: ["lunchtime-lecture"])
        edition = EventEdition.create(panopticon_id: artefact.id, title: artefact.name, start_date: n.days.ago.to_time.utc, state: "published", slug: artefact.slug)
      end
    end

    it "should list the upcoming lectures" do
      get "/lecture-list.json"
      assert last_response.ok?

      json = JSON.parse(last_response.body)

      assert_equal "An event 1 days from now", json['upcoming'][0]['title']
      assert_equal 5, json['upcoming'].count
    end

    it "should list the previous lectures" do
      get "/lecture-list.json"
      assert last_response.ok?

      json = JSON.parse(last_response.body)

      assert_equal "An event 1 days in the past", json['previous'][0]['title']
      assert_equal 10, json['previous'].count
    end

  end

end
