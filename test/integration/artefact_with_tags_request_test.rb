require 'test_helper'

class ArtefactWithTagsRequestTest < GovUkContentApiTest
  should "return 404 if tag not found" do
    Tag.expects(:where).with(tag_id: 'farmers').returns([])

    get "/with_tag.json?tag=farmers"

    assert last_response.not_found?
    assert_status_field "not found", last_response
  end

  should "return the standard response even if zero results" do
    t = Tag.new(tag_id: 'farmers', name: 'Farmers', tag_type: 'Audience')
    Tag.stubs(:where).with(tag_id: 'farmers').returns([t])

    Artefact.expects(:any_in).with(tag_ids: ['farmers']).returns([])

    get "/with_tag.json?tag=farmers"
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_status_field "ok", last_response
    assert_equal 0, parsed_response["total"]
  end


  should "return an array of results" do
    farmers = FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'section')
    FactoryGirl.create(:artefact, owning_app: "smart-answers", sections: ['farmers'])

    get "/with_tag.json?tag=farmers"

    assert last_response.ok?
    assert_equal 1, JSON.parse(last_response.body)["results"].count
  end

  should "exclude unpublished publisher items" do
    farmers = FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'section')
    business = FactoryGirl.create(:tag, tag_id: 'business', title: 'Business', tag_type: 'section')
    artefact = FactoryGirl.create(:artefact, owning_app: "publisher", sections: ['farmers', 'business'])
    FactoryGirl.create(:edition, panopticon_id: artefact.id, state: "ready")

    get "/with_tag.json?tag=farmers"

    assert last_response.ok?, "request failed: #{last_response.status}"
    assert_equal 0, JSON.parse(last_response.body)["results"].count
  end

  should "allow filtering by multiple tags" do
    farmers = FactoryGirl.create(:tag, tag_id: 'farmers', title: 'Farmers', tag_type: 'section')
    business = FactoryGirl.create(:tag, tag_id: 'business', title: 'Business', tag_type: 'section')
    FactoryGirl.create(:artefact, owning_app: "smart-answers", sections: ['farmers', 'business'])

    get "/with_tag.json?tag=farmers,business"
    assert last_response.ok?
    assert_equal 1, JSON.parse(last_response.body)["results"].count
  end
end
