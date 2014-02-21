# config.ru
# A conventional file used for deploying and integrating with some tools
require 'pry-remote'

require "./app"
run Sinatra::Application