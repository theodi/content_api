require 'test_helper'

class CourseInstanceRequest < GovUkContentApiTest
  
  describe "/course-instance.json" do
    it "should redirect to the correct course instance" do
      5.times do |n|
        FactoryGirl.create(:course_instance_edition, course: "this-is-a-course", date: n.days.from_now.to_time.utc)
      end
      
      instance = FactoryGirl.create(:course_instance_edition, state: "published", course: "this-is-a-course", date: 5.days.from_now.to_time.utc)
      date = instance.date.strftime("%Y-%m-%d")
      
      get "/course-instance.json?date=#{date}&course=this-is-a-course"
      assert last_response.redirect?
      assert_equal "http://example.org/#{instance.slug}.json", last_response.location
    end  
  end
  
end