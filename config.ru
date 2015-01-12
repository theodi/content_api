app_path = File.dirname(__FILE__)
$:.unshift(app_path) unless $:.include?(app_path)
%w[ lib ].each do |path|
  $:.unshift path unless $:.include?(path)
end

require 'rubygems'

require 'dotenv'
Dotenv.load

require "bundler"
ENV['RACK_ENV'] ||= 'development'
Bundler.require(:default, ENV['RACK_ENV'])

require "logger"

require "rack/cache"
require "redis-rack-cache"

in_development = ENV['RACK_ENV'] == 'development'
in_preview = ENV['FACTER_govuk_platform'] == 'preview'

if in_development or in_preview
  set :logging, Logger::DEBUG
else
  enable :logging
end

enable :dump_errors, :raise_errors

if ! in_development || ENV["API_CACHE"]
  cache_config_file_path = File.expand_path(
    "rack-cache.#{ENV['RACK_ENV']}.yml",
    File.dirname(__FILE__)
  )
  if File.exists? cache_config_file_path
    template = ERB.new(File.read(cache_config_file_path)).result
    cache_config = YAML.load(template).symbolize_keys
    unless cache_config[:disable_cache] == true
      use Rack::Cache, cache_config
    end
  else
    raise "Cache config file does not exist: #{cache_config_file_path}"
  end
end

unless in_development
  log = File.new("log/production.log", "a")
  STDOUT.reopen(log)
  STDERR.reopen(log)
end

require 'govuk_content_api'
run GovUkContentApi
