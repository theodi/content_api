require "govuk_content_models"
require "govuk_content_models/require_all"
require "odi_content_models"
require "odi_content_models/require_all"
require "govspeak"

module ContentApiArtefactExtensions
  extend ActiveSupport::Concern
  
  included do
    attr_accessor :edition, :assets, :extra_related_artefacts
    scope :live, where(state: 'live')
  end

  def live_related_artefacts
    artefacts = ordered_related_artefacts(related_artefacts.live).to_a
    artefacts += @extra_related_artefacts.to_a if @extra_related_artefacts
    artefacts.uniq(&:slug)
  end
  
  def whole_body
    begin
      Govspeak::Document.new(edition.whole_body, auto_ids: false).to_html
    rescue
      nil
    end
  end
  
  def excerpt
    begin
      text = Nokogiri::HTML(whole_body).inner_text
      text.lines.first.chomp 
    rescue
      nil
    end
  end

  def artist_name
    if edition.respond_to?(:artist)
      artist = Artefact.find_by_slug(edition.artist)
      artist ? artist.name : nil
    end
  end

  def author_edition
    @author_edition ||= begin
      if author
        artefact = Artefact.find_by_slug(author)
        Edition.where(panopticon_id: artefact.id, state: 'published').first rescue nil
      else
        nil
      end
    end
  end

  def node_editions
    @node_editions ||= begin
      if node && !node.empty?
        [node].flatten.map do |x|
          artefact = Artefact.find_by_slug(x)
          Edition.where(panopticon_id: artefact.id, state: 'published').first rescue nil
        end
      else
        []
      end
    end.compact
  end


  def organization_editions
    @organization_editions ||= begin
      if organization_name && !organization_name.empty?
        [organization_name].flatten.map do |x|
          artefact = Artefact.find_by_slug(x)
          Edition.where(panopticon_id: artefact.id, state: 'published').first rescue nil
        end
      else
        []
      end
    end.compact
  end

  def scoped_tag_ids
    scoped_tags = tags.reject {|t| t.tag_type == 'role'}
    scoped_tags.map do |tag|
      tag.tag_id
    end
  end

end

class Artefact
  include ContentApiArtefactExtensions
  
  class << self
    def find_by_slug_and_tag_ids(slug, tag_id)
      where(:slug => slug, :tag_ids => tag_id).first
    end
  end
end
