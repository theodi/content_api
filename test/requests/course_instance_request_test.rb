require 'test_helper'

class CourseInstanceRequest < GovUkContentApiTest
  
  describe "/course-instance.json" do
    def bearer_token_for_user_with_permission
      { 'HTTP_AUTHORIZATION' => 'Bearer xyz_has_permission_xyz' }
    end
    
    before :each do
      @startdate = 5.days.from_now.to_time.utc
      @date_str = @startdate.strftime("%Y-%m-%d")
      @artefact = FactoryGirl.create(:artefact, 
        kind: "course_instance",
        slug: "this-is-a-course-#{@date_str}",
        state: "live")
      @edition1 = FactoryGirl.create(:course_instance_edition, 
        slug: "this-is-a-course-#{@date_str}",
        panopticon_id: @artefact.id,
        state: "published", 
        course: "this-is-a-course", 
        version_number: 1,
        date: @startdate)
      @newstartdate = 6.days.from_now.to_time.utc
      @edition2 = FactoryGirl.create(:course_instance_edition, 
        slug: "this-is-a-course-#{@date_str}",
        panopticon_id: @artefact.id,
        course: "this-is-a-course",
        version_number: 2,
        date: @newstartdate)
    end
    
    it "should give correct course instance" do    
      get "/course-instance.json?date=#{@date_str}&course=this-is-a-course"
      assert last_response.ok?
      json = JSON.parse(last_response.body)
      assert_equal "this-is-a-course", json['details']['course']
      assert_equal @startdate.to_datetime.to_s, DateTime.parse(json['details']['date']).to_s
    end
    
    it "should handle edition param for unpublished items" do
      Warden::Proxy.any_instance.expects(:authenticate?).returns(true)
      Warden::Proxy.any_instance.expects(:user).returns(ReadOnlyUser.new("permissions" => ["access_unpublished"]))
      
      get "/course-instance.json?date=#{@date_str}&course=this-is-a-course&edition=2"
      assert last_response.ok?
      json = JSON.parse(last_response.body)
      assert_equal "this-is-a-course", json['details']['course']
      assert_equal @newstartdate.to_datetime.to_s, DateTime.parse(json['details']['date']).to_s
    end
  
    it "should give correct course instance" do    
      get "/course-instance.json?date=#{@date_str}&course=this-is-a-course"
      assert last_response.ok?
      json = JSON.parse(last_response.body)
      assert_equal "https://www.gov.uk/courses/this-is-a-course/#{@date_str}", json['web_url']
    end
    
  end
  
end