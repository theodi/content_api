require_relative '../test_helper'

class TravelAdviceTest < GovUkContentApiTest

  describe "loading a list of travel advice countries" do
    it "should return an alphabetical list of countries with published editions" do
      edition1 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'afghanistan')
      edition2 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'angola')
      edition3 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'andorra')

      get '/foreign-travel-advice.json'
      assert last_response.ok?

      parsed_response = JSON.parse(last_response.body)

      assert_equal 3, parsed_response["total"]
      assert_equal 3, parsed_response["results"].length

      assert_equal ["Afghanistan", "Andorra", "Angola"], parsed_response["results"].map {|c| c["name"]}

      first = parsed_response["results"].first
      assert_equal "Afghanistan", first["name"]
      assert_equal "afghanistan", first["identifier"]
      assert_equal "http://example.org/foreign-travel-advice%2Fafghanistan.json", first["id"]
      assert_equal "https://www.gov.uk/foreign-travel-advice/afghanistan", first["web_url"]
      assert_equal edition1.updated_at.xmlschema, first["updated_at"]
    end

    it "should not include countries without published editions" do
      edition1 = FactoryGirl.create(:archived_travel_advice_edition, country_slug: 'afghanistan')
      edition2 = FactoryGirl.create(:draft_travel_advice_edition, country_slug: 'angola')
      edition3 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'andorra')

      get '/foreign-travel-advice.json'
      assert last_response.ok?

      parsed_response = JSON.parse(last_response.body)

      assert_equal 1, parsed_response["results"].length
      assert_equal ["Andorra"], parsed_response["results"].map {|c| c["name"]}
    end

    it "should not include published editions for a non-existent country" do
      edition1 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'afghanistan',
                                  alert_status: ["avoid_all_but_essential_travel_to_parts","avoid_all_travel_to_parts"])
      edition2 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'angola')
      edition3 = FactoryGirl.create(:published_travel_advice_edition, country_slug: 'narnia')

      get '/foreign-travel-advice.json'
      assert last_response.ok?

      parsed_response = JSON.parse(last_response.body)

      assert_equal 2, parsed_response["results"].length
      assert_equal ["Afghanistan", "Angola"], parsed_response["results"].map {|c| c["name"]}
    end
  end

  describe "loading data for a travel advice country page" do

    it "should return details for a country with published advice" do
      artefact = FactoryGirl.create(:artefact, slug: 'foreign-travel-advice/aruba', state: 'live',
                                    kind: 'travel-advice', owning_app: 'travel-advice-publisher', name: "Aruba travel advice",
                                    description: "This is the travel advice for people planning a visit to Aruba.")
      edition = FactoryGirl.build(:travel_advice_edition, country_slug: 'aruba',
                                  title: "Travel advice for Aruba", overview: "This is the travel advice for people planning a visit to Aruba.",
                                  summary: "This is the summary\n------\n",
                                  alert_status: ["avoid_all_but_essential_travel_to_parts","avoid_all_travel_to_parts"])
      edition.parts.build(title: "Part One", slug: 'part-one', body: "This is part one\n------\n")
      edition.parts.build(title: "Part Two", slug: 'part-two', body: "And some more stuff in part 2.")
      edition.save!
      edition.publish!

      get '/foreign-travel-advice%2Faruba.json'
      assert last_response.ok?

      parsed_response = JSON.parse(last_response.body)

      assert_base_artefact_fields(parsed_response)
      assert_equal 'travel-advice', parsed_response["format"]
      assert_equal 'Travel advice for Aruba', parsed_response["title"]

      details = parsed_response["details"]
      assert_equal 'This is the travel advice for people planning a visit to Aruba.', details['description']
      assert_equal '<h2>This is the summary</h2>', details['summary'].strip
      assert_equal ["avoid_all_but_essential_travel_to_parts","avoid_all_travel_to_parts"], details['alert_status']

      # Country details
      assert_equal({"name" => "Aruba", "slug" => "aruba"}, details["country"])

      # Parts
      parts = details["parts"]
      assert_equal 2, parts.length

      assert_equal "Part One", parts[0]["title"]
      assert_equal "part-one", parts[0]["slug"]
      assert_equal "<h2>This is part one</h2>", parts[0]["body"].strip

      assert_equal "Part Two", parts[1]["title"]
      assert_equal "part-two", parts[1]["slug"]
      assert_equal "<p>And some more stuff in part 2.</p>", parts[1]["body"].strip
    end

    it "should 404 for a country with no published advice" do
      get '/foreign-travel-advice%2Fangola.json'
      assert last_response.not_found?
    end

    it "should 404 for a non-existent country" do
      get '/foreign-travel-advice%2Fwibble.json'
      assert last_response.not_found?
    end
  end
end