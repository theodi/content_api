require "test_helper"
require "pagination"

class PaginatedSearchResultSet < MiniTest::Spec

  include Pagination

  describe "PaginatedSearchResultSet" do

    it "gives the appropriate response when given a search result" do
      stub_request(:get, "http://search.#{ENV["GOVUK_APP_DOMAIN"]}/unified_search.json?q=space&index=odi&start=0")
                  .to_return(:body => File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'unified_search.json')), :status => 200)

      client = GdsApi::Rummager.new("http://search.#{ENV["GOVUK_APP_DOMAIN"]}")

      result = client.unified_search({q: "space", index: "odi", start: "0"})
      result_set = PaginatedSearchResultSet.new(result)

      assert_equal result_set.start_index, 0
      assert_equal result_set.total, 76
      assert_equal result_set.pages, 8
      assert_equal result_set.page_size, 10
      assert_equal result_set.current_page, 1
      assert_equal result_set.first_page?, true
      assert_equal result_set.last_page?, false
    end

    it "gives the appropriate response when given the last page of a search result" do
      stub_request(:get, "http://search.#{ENV["GOVUK_APP_DOMAIN"]}/unified_search.json?q=space&index=odi&start=70")
                  .to_return(:body => File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'last_page.json')), :status => 200)

      client = GdsApi::Rummager.new("http://search.#{ENV["GOVUK_APP_DOMAIN"]}")

      result = client.unified_search({q: "space", index: "odi", start: "70"})
      result_set = PaginatedSearchResultSet.new(result)

      assert_equal result_set.current_page, 8
      assert_equal result_set.first_page?, false
      assert_equal result_set.last_page?, true
    end

  end

end
