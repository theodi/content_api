require 'test_helper'

class SearchRequestTest < GovUkContentApiTest
  it "should 404 when asked for a bad index" do
    skip("WARNING: the index is hard coded in rummager atm,
      once that is no longer true, this should be re-instated")
    get "/search.json?q=government&index=fake"
    assert last_response.not_found?
  end

  def sample_results
    [
      {
        'title' => "Nick Harvey MP (Minister of State (Minister for the Armed Forces), Ministry of Defence)",
        'link' => "/government/ministers/minister-of-state-minister-for-the-armed-forces",
        'format' => "minister",
        'description' => "Nick Harvey was appointed Minister for the Armed Forces in May 2010. He is the MP for North Devon.",
        'indexable_content' => "Nick Harvey was appointed Minister for the Armed Forces in May 2010. He is the MP for North Devon.",
        'highlight' => nil,
        'presentation_format' => "minister",
        'humanized_format' => "Ministers"
      },
      {
        'title' => "Armed Forces Compensation Scheme",
        'link' => "/armed-forces-compensation-scheme",
        'format' => "programme",
        'section' => "work",
        'subsection' => "work-related-benefits-and-schemes",
        'description' => "Overview The Armed Forces Compensation Scheme helps to support",
        'indexable_content' => "Overview The Armed Forces Compensation Scheme helps to support",
        'highlight' => nil,
        'presentation_format' => "programme",
        'humanized_format' => "Benefits & credits"
      }
    ]
  end

  it "should return an array of results" do
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns("results" => sample_results)
    get "/search.json?q=government+info"
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_equal 2, parsed_response["total"]
    assert_equal 2, parsed_response["results"].count
    assert_equal 'Nick Harvey MP (Minister of State (Minister for the Armed Forces), Ministry of Defence)',
      parsed_response["results"].first['title']
  end

  it "should return the standard response even if zero results" do
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns("results" => [])

    get "/search.json?q=empty+result+set"
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    assert_equal 0, parsed_response["total"]
  end

  it "should return a semantic error if missing query" do
    GdsApi::Rummager.any_instance.expects(:unified_search).never

    get "/search.json?q=++"
    parsed_response = JSON.parse(last_response.body)

    assert_equal 422, last_response.status
    assert_status_field "unprocessable", last_response
    assert_status_message(
      "Non-empty querystring is required in the 'q' parameter",
      last_response
    )
  end

  it "should include proper URLs for each response" do
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns("results" => sample_results)
    get "/search.json?q=government+info"

    assert last_response.ok?

    parsed_response = JSON.parse(last_response.body)
    first_response = parsed_response['results'][0]

    assert ! URI.parse(first_response['id']).host.nil?,
      "ID doesn't have a hostname"
    assert ! URI.parse(first_response['web_url']).host.nil?,
      "web_url doesn't have a hostname"
  end

  it "should return 503 if connection times out" do
    GdsApi::Rummager.any_instance.stubs(:unified_search).raises(GdsApi::TimedOutException)
    get "/search.json?q=government"

    assert_equal 503, last_response.status
  end

  it "should return a valid web_url for recommended-links (off-site links)" do
    rummager_response = {
      "results" => [
        {
          "title" => "EHIC - NHS Choices",
          "description" => "Apply for a free European Health Insurance Card (EHIC) or renew your card for emergency healthcare in Europe",
          "format" => "recommended-link",
          "link" => "http://www.nhs.uk/ehic",
          "indexable_content" => "ehic, e111, european health insurance card, european health card, travel abroad, travel insurance",
          "es_score" => 3.3209536,
          "highlight" => nil,
          "presentation_format" => "recommended_link",
          "humanized_format" => "Recommended links"}
      ]
    }
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns(rummager_response)
    get "/search.json?q=ehic"

    parsed_response = JSON.parse(last_response.body)
    assert_equal 'http://www.nhs.uk/ehic', parsed_response["results"].first['web_url']
  end

  it "should omit id values for recommended-links (off-site links)" do
    rummager_response = {
      "results" => [
        {
          "title" => "EHIC - NHS Choices",
          "description" => "Apply for a free European Health Insurance Card (EHIC) or renew your card for emergency healthcare in Europe",
          "format" => "recommended-link",
          "link" => "http://www.nhs.uk/ehic",
          "indexable_content" => "ehic, e111, european health insurance card, european health card, travel abroad, travel insurance",
          "es_score" => 3.3209536,
          "highlight" => nil,
          "presentation_format" => "recommended_link",
          "humanized_format" => "Recommended links"}
      ]
    }
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns(rummager_response)
    get "/search.json?q=ehic"

    parsed_response = JSON.parse(last_response.body)
    assert_equal nil, parsed_response["results"].first['id']
  end

  it "should include created at date" do
    FactoryGirl.create(:tag, :tag_id => "dapaas", :tag_type => 'role', :title => "dapaas")
    artefact = FactoryGirl.create(:my_artefact, state: 'live', slug: 'treating-content-as-data', roles: ['dapaas'])
    edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')
    rummager_response = {
      "results" =>  [
          'title' => "Treating content as data",
          'format' => "article",
          'link' => "/treating-content-as-data",
          'index' => "dapaas",
          'es_score' => "0.00087927346",
          '_id' => "/treating-content-as-data"
      ]
    }
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns(rummager_response)
    get "/search.json?q=treating"
    parsed_response = JSON.parse(last_response.body)

    assert_equal artefact.created_at, parsed_response["results"].first['details']['created_at']
  end

  it "should include tag ids" do
    FactoryGirl.create(:tag, :tag_id => "dapaas", :tag_type => 'role', :title => "dapaas")
    artefact = FactoryGirl.create(:my_artefact, state: 'live', slug: 'treating-content-as-data', roles: ['dapaas'])
    edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')
    rummager_response = {
      "results" =>  [
          'title' => "Treating content as data",
          'format' => "article",
          'link' => "/treating-content-as-data",
          'index' => "dapaas",
          'es_score' => "0.00087927346",
          '_id' => "/treating-content-as-data"
      ]
    }
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns(rummager_response)
    get "/search.json?q=treating"
    parsed_response = JSON.parse(last_response.body)

    assert_equal artefact.tag_ids, parsed_response["results"].first['details']['tag_ids']
  end

  it "should include the artefact's format" do
    FactoryGirl.create(:tag, tag_id: "dapaas", tag_type: 'role', title: "dapaas")
    FactoryGirl.create(:tag, tag_id: "blog", tag_type: 'article', title: "blog")

    artefact = FactoryGirl.create(:my_artefact,
                                  state: 'live',
                                  slug: 'treating-content-as-data',
                                  roles: ['dapaas'],
                                  kind: 'article',
                                  article: ['blog']
                                )
    edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')

    rummager_response = {
      "results" =>  [
          'title' => "Treating content as data",
          'format' => "article",
          'link' => "/treating-content-as-data",
          'index' => "dapaas",
          'es_score' => "0.00087927346",
          '_id' => "/treating-content-as-data"
      ]
    }

    GdsApi::Rummager.any_instance.stubs(:unified_search).returns(rummager_response)
    get "/search.json?q=treating"
    parsed_response = JSON.parse(last_response.body)

    assert_equal 'blog', parsed_response["results"].first['details']['format']
  end

  it "should include the artefact's slug" do
    FactoryGirl.create(:tag, :tag_id => "dapaas", :tag_type => 'role', :title => "dapaas")
    artefact = FactoryGirl.create(:my_artefact, state: 'live', slug: 'treating-content-as-data', roles: ['dapaas'])
    edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')
    rummager_response = {
      "results" =>  [
          'title' => "Treating content as data",
          'format' => "article",
          'link' => "/treating-content-as-data",
          'index' => "dapaas",
          'es_score' => "0.00087927346",
          '_id' => "/treating-content-as-data"
      ]
    }
    GdsApi::Rummager.any_instance.stubs(:unified_search).returns(rummager_response)
    get "/search.json?q=treating"
    parsed_response = JSON.parse(last_response.body)

    assert_equal artefact.slug, parsed_response["results"].first['details']['slug']
  end

end
