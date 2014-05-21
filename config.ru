# config.ru
# A conventional file used for deploying and integrating with some tools
require 'pry'
require 'pry-remote'

require 'sidekiq'
require 'sidekiq/web'
require 'redis'

require "./app"

# Enable Sidekiq webvew
# @todo (ensure this is only visible to me, maybe?)
# https://github.com/mperham/sidekiq/wiki/Monitoring#standalone-with-basic-auth
run Rack::URLMap.new('/sidekiq' => Sidekiq::Web, '/' => Sinatra::Application)