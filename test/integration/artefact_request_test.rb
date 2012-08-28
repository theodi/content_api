require 'test_helper'

class ArtefactRequestTest < GovUkContentApiTest
  should "return 404 if artefact not found" do
    Artefact.expects(:where).with(slug: 'bad-artefact').returns([])
    get '/bad-artefact.json'
    assert last_response.not_found?
    assert_equal 'not found', JSON.parse(last_response.body)["response"]["status"]
  end

  should "return 404 if artefact is publication but never published" do
    stub_artefact = Artefact.new(slug: 'unpublished-artefact', owning_app: 'publisher')
    Artefact.stubs(:where).with(slug: 'unpublished-artefact').returns([stub_artefact])
    Edition.stubs(:where).with(slug: 'unpublished-artefact', state: 'published').returns([])
    Edition.stubs(:where).with(slug: 'unpublished-artefact', state: 'archived').returns([])

    get '/unpublished-artefact.json'

    assert last_response.not_found?
    assert_equal 'not found', JSON.parse(last_response.body)["response"]["status"]
  end

  should "return 410 if artefact is publication but only archived" do
    stub_artefact = Artefact.new(slug: 'archived-artefact', owning_app: 'publisher')
    Artefact.stubs(:where).with(slug: 'archived-artefact').returns([stub_artefact])
    Edition.stubs(:where).with(slug: 'archived-artefact', state: 'published').returns([])
    Edition.stubs(:where).with(slug: 'archived-artefact', state: 'archived').returns(['not empty'])

    get '/archived-artefact.json'

    assert_equal 410, last_response.status
    assert_equal 'gone', JSON.parse(last_response.body)["response"]["status"]
  end

  should "return publication data if published" do
    stub_artefact = Artefact.new(slug: 'published-artefact', owning_app: 'publisher')
    stub_answer = AnswerEdition.new(body: 'Important information')

    Artefact.stubs(:where).with(slug: 'published-artefact').returns([stub_artefact])
    Edition.stubs(:where).with(slug: 'published-artefact', state: 'published').returns([stub_answer])

    get '/published-artefact.json'
    parsed_response = JSON.parse(last_response.body)

    assert last_response.ok?
    
    assert_equal 'ok', parsed_response["response"]["status"]
    assert_equal "Important information", parsed_response["response"]["result"]["fields"]["body"]
  end

  should "not look for edition if publisher not owner" do
    stub_artefact = Artefact.new(slug: 'smart-answer', owning_app: 'smart-answers')
    Artefact.stubs(:where).with(slug: 'smart-answer').returns([stub_artefact])
    Edition.expects(:where).never

    get '/smart-answer.json'

    assert last_response.ok?
    assert_equal 'ok', JSON.parse(last_response.body)["response"]["status"]
  end
end