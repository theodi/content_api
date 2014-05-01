class SearchResultPresenter

  def initialize(result, url_helper)
    @result = result
    @url_helper = url_helper
  end

  def present
    result = {
      "id" => search_result_url(@result),
      "web_url" => search_result_web_url(@result),
      "title" => @result["title"],
      "details" => {
        "description" => @result["description"],
      }
    }
    add_artefact_details(result)
  end

  def add_artefact_details(result)
    if @result["artefact"]
      result["details"]["slug"] = @result["artefact"].slug
      result["details"]["tag_ids"] = @result["artefact"].tag_ids
      result["details"]["format"] = format
      result["details"]["created_at"] = @result["artefact"].created_at
    end
    result
  end

private
  def search_result_url(result)
    if result['link'].start_with?("http")
      nil
    else
      @url_helper.api_url(result['link']) + ".json"
    end
  end

  def search_result_web_url(result)
    if result['link'].start_with?("http")
      result['link']
    else
      @url_helper.public_web_url(result['link'])
    end
  end

  def format
    t = @result["artefact"].tag_ids.select do |t|
      Tag.where(tag_id: t, tag_type: @result["artefact"].kind).count > 0
    end

    if t.count == 0
      @result["artefact"].kind
    else
      t.first
    end
  end
end
