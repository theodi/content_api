require 'test_helper'
require 'uri'
require 'gds_api/test_helpers/asset_manager'

class AssetRedirectTest < GovUkContentApiTest
  include GdsApi::TestHelpers::AssetManager

  describe ":slug/image" do

    before :each do
      asset_manager_has_an_asset("512c9019686c82191d000001", {
        "id" => "http://asset-manager.#{ENV["GOVUK_APP_DOMAIN"]}/assets/512c9019686c82191d000001",
        "name" => "darth-on-a-cat.jpg",
        "content_type" => "image/jpeg",
        "file_url" => "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat.jpg",
        "file_versions" => {
          "square" => "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat-square.jpg"
        },
        "state" => "clean",
      })

      @artefact = FactoryGirl.create(:my_artefact, :state => 'live')
      @edition = FactoryGirl.create(:person_edition, panopticon_id: @artefact.id, state: 'published', image_id: '512c9019686c82191d000001')
    end

    it "redirects to the image" do
      get "#{@artefact.slug}/image"

      assert last_response.redirect?
      follow_redirect!
      assert_equal "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat.jpg", last_request.url
    end

    it "redirects to the square version" do
      get "#{@artefact.slug}/image?version=square"

      assert last_response.redirect?
      follow_redirect!
      assert_equal "https://assets.digital.cabinet-office.gov.uk/media/512c9019686c82191d000001/darth-on-a-cat-square.jpg", last_request.url
    end

    it "404s if the version does not exist" do
      get "#{@artefact.slug}/image?version=bogus"
      assert last_response.not_found?
    end

    it "404s if the edition isn't a person" do
      artefact = FactoryGirl.create(:my_artefact, :state => 'live')
      edition = FactoryGirl.create(:edition, panopticon_id: artefact.id, state: 'published')
      get "#{artefact.slug}/image"

      assert last_response.not_found?
    end

    it "404s if there is no image" do
      artefact = FactoryGirl.create(:my_artefact, :state => 'live')
      edition = FactoryGirl.create(:person_edition, panopticon_id: artefact.id, state: 'published', image_id: nil)

      get "#{artefact.slug}/image"

      assert last_response.not_found?
    end

  end

end
