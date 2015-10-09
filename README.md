bitbooks.cc
===========

This is a Sinatra application, running bitbooks.cc. Its components include:

* A Sinatra application --- Serves the main website
* A Sidekiq process --- Provides background jobs for processing
* A Postgresql database --- Stores records of users and books (it is Sqlite in development)

Sidekiq uses HTTP requests to send jobs to Bitbinder, a second application that
pulls content from github, builds it into a book, and pushes the result to
github pages.


## Local development

1. Clone down this repo as well as the bitbinder repo.
2. Install dependencies:
  * Homebrew: `ngrok`, `redis`, `postgresql`
  * Ruby: `bundle install` (for both repos)
3. Set Environment Variables
```bash
GH_BASIC_SECRET_ID  # Github Authentication Secret
GH_BASIC_CLIENT_ID  # Github Authentication Login ID
BITBOOKS_ROOT       # Domain for the Bitbooks App
BITBINDER_ROOT      # Domain for the Bitbinder App
SECRET_KEY          # Key for encrypting user Oauth Tokens
SESSION_SECRET      # Secret for preserving user sessions.
HOOK_SECRET         # Secret for authenticating incoming Github webhook requests
BITBOOKS_PASS       # Password for secure API requests between bitbooks & bitbinder. Also logs into sidekiq admin panel.
```

### Start all local processes
```bash
# Setup Bitbinder
cd bitbinder
b rackup

# Setup Sidekiq
cd bitbooks.cc
redis-server
b sidekiq -r ./app.rb -c 1

# Setup Bitbooks.cc
b tux

# Setup Ngrok
./vendor/ngrok 9393

# Setup an Endpoint for API requests (optional)
export BITBOOKS_ROOT=http://xxxxxxxx.ngrok.com
cd bitbooks.cc
b shotgun
```

## Production
Production was set up on an Ubuntu machine running docker and  with three docker containers:

1. Bitbooks.cc (the main CRUD app)
2. Bitbinder (the static site builder)
3. Postgresql (the production database for bitbooks.cc - running *postgresql-client*)

We used [Dokku](https://github.com/progrium/dokku) to deploy to product through a git interface, similar to heroku. Dokku plugins included:
- dokku-supervisord
- dokku-rebuild
