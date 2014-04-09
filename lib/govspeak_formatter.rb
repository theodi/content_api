class GovspeakFormatter

  EMBEDDED_FACT_REGEXP = /\[fact\:([a-z0-9-]+)\]/i # e.g. [fact:vat-rates]

  def initialize(format, fact_cave_api=nil)
    unless [:html, :govspeak].include? format
      raise ArgumentError.new("Invalid format #{format}")
    end

    @format = format
    @fact_cave_api = fact_cave_api
  end

  def format(govspeak_string)
    if @format == :html
      formatted = Govspeak::Document.new(govspeak_string, auto_ids: false).to_html
    else
      formatted = govspeak_string
    end
  end
end