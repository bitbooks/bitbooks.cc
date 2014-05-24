# Gemfile
source 'https://rubygems.org'
ruby '2.0.0'

gem "rake"
gem "compass"
gem "sinatra"
gem "activerecord"
gem "sinatra-activerecord"
gem "sinatra-flash"
gem "rest-client"
gem "json"
gem "octokit", "~> 2.0"
gem "sidekiq"
gem "redis"
gem "attr_encrypted"

group :development do
  gem "sqlite3"
  gem "shotgun"
  # For debugging.
  gem "tux"
  gem "pry", :require => true
  gem "pry-remote", :require => true
end

group :production do
  gem "pg"
end
