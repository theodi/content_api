module ContentApiSectionExtensions  
  extend ActiveSupport::Concern
  included do
    attr_accessor :assets
  end
end

class Section
  include ContentApiSectionExtensions
end

class SectionModule
  include ContentApiSectionExtensions
end