source 'https://rubygems.org'

ruby "1.9.3"

gem 'puma'
gem 'foreman', '< 0.84.0'
gem 'rake', '12.0.0'
gem 'rack-protection', "< 1.5.1" # pinned due to slash-encoding change
gem 'sinatra', '1.4.6'
gem 'statsd-ruby', '1.0.0'
gem 'dotenv'

gem 'govuk_content_models', '6.1.0'

if ENV['CONTENT_MODELS_DEV']
  gem "odi_content_models", path: '../odi_content_models'
else
  gem "odi_content_models", github: 'theodi/odi_content_models'
end

# Pinning mongo to prevent bundler downgrading it in order to upgrade bson
# (as seen in 680d3e9ab7)
gem 'mongo', '>= 1.7.1'

gem 'gds-sso', '9.4.0'

gem 'gds-api-adapters', :github => 'theodi/gds-api-adapters'

if ENV['ODIDOWN_DEV']
  gem 'odidown', path: '../odidown'
else
  gem 'odidown', github: 'theodi/odidown'
end

gem 'plek', '2.0.0'
# gem 'router-client', '3.1.0', :require => false # No longer available
gem 'yajl-ruby'
gem 'aws-ses', '0.6.0'
gem 'kaminari', '0.14.1'
gem 'link_header', '0.0.8'
gem 'airbrake', '~> 4.3.0'

group :test do
  gem 'database_cleaner', '1.6.1'
  gem 'factory_girl', '4.8.0'
  gem 'mocha', '0.12.4', require: false
  gem 'simplecov', '0.14.1'
  gem 'simplecov-rcov', '0.2.3'
  gem 'minitest', '3.4.0'
  gem 'turn', require: false
  gem 'ci_reporter', '1.7.0'
  gem 'webmock', '~> 1.8', require: false
  gem 'timecop', '0.8.1'
  gem 'pry'
end

group :development do
  gem "shotgun"
end

group :production do
  gem "rails_12factor"
end
