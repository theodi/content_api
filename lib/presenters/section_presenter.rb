class SectionPresenter
  def initialize(section, url_helper)
    @section = section
    @url_helper = url_helper
  end

  def present
    {
      "title" => @section.title,
      "link" => @section.link,
      "description" => @section.description,
      "hero" => hero_asset,
      "modules" => modules
    }
  end

private
  def modules
    presented_modules = @section.modules.map do |section_module|
      ModulePresenter.new(
        section_module,
        @url_helper
      ).present
    end
  end

  def hero_asset
    begin
      @section.assets[:hero_image].file_url
    rescue NoMethodError
      nil
    end
  end
end