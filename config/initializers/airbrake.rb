require 'airbrake'

configure :production do
  Airbrake.configure do |config|
    config.api_key = ENV['QUIRKAFLEEG_AIRBRAKE_KEY']
  end
  use Airbrake::Sinatra
end
