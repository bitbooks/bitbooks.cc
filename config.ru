# config.ru
# A conventional file used for deploying and integrating with some tools
# Used for loading the application.

require 'sidekiq'
require 'sidekiq/web'
require 'redis'

require "./app"

# Run both the main app and the sidekiq app
# @todo (ensure Sidekiq webview is only visible to me, maybe?)
# https://github.com/mperham/sidekiq/wiki/Monitoring#standalone-with-basic-auth
run Rack::URLMap.new('/sidekiq' => Sidekiq::Web, '/' => Sinatra::Application)