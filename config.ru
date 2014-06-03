# config.ru
# A conventional file used for deploying and integrating with some tools
# Used for loading the application.

require 'sidekiq'
require 'sidekiq/web'
require 'redis'

require './app'

# Run both the main app and the sidekiq app
BITBOOKS_PASS = ENV['BITBOOKS_PASS'] || '12345'

map '/' do
  run Sinatra::Application
end

map '/admin/sidekiq' do
  use Rack::Auth::Basic, 'Restricted Area' do |username, password|
    username == 'bitbooks' && password == BITBOOKS_PASS
  end

  run Sidekiq::Web
end

# There must be one blank newline at the end of this file, or Tux will choke.
