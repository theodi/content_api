require 'test_helper'

class CourseInstanceRequest < GovUkContentApiTest
  
  describe "/course-instance.json" do
    def bearer_token_for_user_with_permission
      { 'HTTP_AUTHORIZATION' => 'Bearer xyz_has_permission_xyz' }
    end
    
    before :each do
      5.times do |n|
        FactoryGirl.create(:course_instance_edition, course: "this-is-a-course", date: n.days.from_now.to_time.utc)
      end
      
      @instance = FactoryGirl.create(:course_instance_edition, state: "published", course: "this-is-a-course", date: 5.days.from_now.to_time.utc)
      @date = @instance.date.strftime("%Y-%m-%d")
    end
    
    it "should redirect to the correct course instance" do    
      get "/course-instance.json?date=#{@date}&course=this-is-a-course"
      assert last_response.redirect?
      assert_equal "http://example.org/#{@instance.slug}.json", last_response.location
    end
    
    it "should redirect with an edition when the edition param is added" do
      Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
      Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => ["access_unpublished"]))
      
      get "/course-instance.json?date=#{@date}&course=this-is-a-course&edition=1"
      assert last_response.redirect?
      assert_equal "http://example.org/#{@instance.slug}.json?edition=1", last_response.location
      
      get last_response.header["Location"], {}, { 'HTTP_AUTHORIZATION' => 'Bearer xyz_has_permission_xyz' }
    end
  end
  
end