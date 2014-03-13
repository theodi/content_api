class ModulePresenter
  def initialize(section_module, url_helper)
    @module = section_module
    @url_helper = url_helper
  end

  def present
    presented = {
      "title" => @module.title,
      "type" => @module.type
    }
    presented.merge(type_attributes)
  end

private
  
  def type_attributes
    if @module.type == "Text"
      {
        "text" => @module.text,
        "colour" => @module.colour,
        "link" => @module.link
      }
    elsif @module.type == "Image"
      {
        "image" => @module.assets[:image].file_url,
        "link" => @module.link
      }
    elsif @module.type == "Frame"
      {"frame" => @module.frame}
    end
  end
end