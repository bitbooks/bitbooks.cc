# Rakefile
# Defines helpful rake tasks we can run from command line.
# See: http://rake.rubyforge.org/doc/rakefile_rdoc.html

# These followig four require statements are needed to create migrations,
# however, deploying them uncommented causes the Invalid DATABASE_URL errors
# to appear (though the deployment still seems to work). It's probably best
# to leave them commented unless I'm doing migrations.
 require 'sidekiq'
 require 'sidekiq/web'
 require 'redis'
 require './app'

require 'sinatra/activerecord/rake' # Defines migration tasks.
