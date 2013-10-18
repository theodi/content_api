require "govuk_content_models"
require "govuk_content_models/require_all"
require "odi_content_models"
require "odi_content_models/require_all"
require "govspeak"

module ContentApiArtefactExtensions
  extend ActiveSupport::Concern
  
  attr_accessor :author_name, :author_slug

  included do
    attr_accessor :edition, :licence, :places, :assets, :country, :extra_related_artefacts
    scope :live, where(state: 'live')
  end

  def live_related_artefacts
    artefacts = ordered_related_artefacts(related_artefacts.live).to_a
    artefacts += @extra_related_artefacts.to_a if @extra_related_artefacts
    artefacts.uniq(&:slug)
  end
  
  def excerpt
    begin
      html = Govspeak::Document.new(edition.whole_body, auto_ids: false).to_html
      text = Nokogiri::HTML(html).inner_text
      text.lines.first.chomp 
    rescue
      nil
    end
  end

end

class Artefact
  include ContentApiArtefactExtensions
end
