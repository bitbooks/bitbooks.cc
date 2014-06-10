# app.rb
# The guts of our Sinatra app

require 'bundler'
require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/flash'
require 'rest-client'
require 'json'
require 'octokit'
require 'attr_encrypted'
# for pretty print debugging
require 'pp'

# Environment Variables (with dummy placeholders)
CLIENT_ID = ENV['GH_BASIC_CLIENT_ID'] || '12345'
CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID'] || '12345'
SESSION_SECRET = ENV['SESSION_SECRET'] || '12345'
SECRET_KEY = ENV['SECRET_KEY'] || '12345'
HOOK_SECRET = ENV['HOOK_SECRET'] || '12345'
BITBOOKS_PASS = ENV['BITBOOKS_PASS'] || '12345'
BITBOOKS_ROOT = ENV['BITBOOKS_ROOT'] || 'http://127.0.0.1:9393'
BITBINDER_ROOT = ENV['BITBINDER_ROOT'] || 'http://127.0.0.1:9292'

# Needed for making persistant messages with the sinatra/flash gem, and for
# preserving user sessions.
enable :sessions
set :session_secret, SESSION_SECRET


# I can query database objects with the Active Record Querying Interface
# (see: http://guides.rubyonrails.org/active_record_querying.html)
#
# Examples:
# Book.count #=> Counts the number of records in the books table
# Book.All #=> Returns all books. Equivalent to SELECT * from books;
#
class Book < ActiveRecord::Base
  belongs_to :user
end
class User < ActiveRecord::Base
  has_many :books
  attr_encrypted :token, :key => SECRET_KEY
end


######################################
# Github Auth
#
# Based on this awesome tutorial:
# http://developer.github.com/guides/basics-of-authentication/
######################################

# @todo: Re-evaluate this authentication because it's just based on an encrypted
# github_id, and it is used for access restrictions.
def authenticated?
  session[:github_id]
end

def authenticate!
  message = 'Please <a href="https://github.com/login/oauth/authorize?scope=public_repo,admin:repo_hook&client_id=' + CLIENT_ID + '">login with Github</a> to continue.'
  flash[:info] = message
  redirect '/'
end

# Methods for restricting access to bitbooks-only internal API endpoints.
# See http://www.sinatrarb.com/faq.html#auth
def protected!
  return if from_bitbooks?
  headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
  halt 401, "Not authorized\n"
end

def from_bitbooks?
  @auth ||=  Rack::Auth::Basic::Request.new(request.env)
  @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == ['bitbooks', BITBOOKS_PASS]
end

######################################
# Async Queue setup
# Example: https://github.com/mperham/sidekiq/blob/master/examples/sinkiq.rb
######################################

# For this to work make sure you have Sinatra installed, and redis installed
# (see http://stackoverflow.com/a/13635955/1154642). Start redis with:
#
#   redis-server
#
# then start sidekiq with
#
#   bundle exec sidekiq -r ./app.rb
#

$redis = Redis.new

class BuildWorker
  include Sidekiq::Worker

  # require 'pry'

  # Define the action that we want the worker to do.
  def perform(book_id)
    # We are sending the book's unique data (the contents of book.yml)
    # over in a post request. This will be used to build the book.
    book = Book.find(book_id)
    book_info = book.attributes
    book_info['token'] = User.find(book.user_id).encrypted_token

    response = RestClient::Request.new(
      :method => :post,
      :url => BITBINDER_ROOT + '/build',
      :user => 'bitbooks',
      :password => BITBOOKS_PASS,
      :payload => { :data => book_info.to_json },
      :headers => { :content_type => :json, :accept => :json }
    ).execute

    # Throw in a message, for testing purposes.
    # $redis.lpush('sinkiq-example-messages', response)
  end
end

class CopyWorker
  include Sidekiq::Worker

  # require 'pry-remote'

  # Define the action that we want the worker to do.
  def perform(book_id)
    # We are sending the book's unique data (the contents of book.yml)
    # over in a post request. This will be used to build the book.
    book = Book.find(book_id)
    book_info = book.attributes
    book_info['token'] = User.find(book.user_id).encrypted_token

    response = RestClient::Request.new(
      :method => :post,
      :url => BITBINDER_ROOT + '/copy',
      :user => 'bitbooks',
      :password => BITBOOKS_PASS,
      :payload => { :data => book_info.to_json },
      :headers => { :content_type => :json, :accept => :json }
    ).execute

    # If the repo exists, kick off the next workers.
    BuildWorker.perform_async(book_id)
    UpdateWorker.perform_async(book_id)
  end
end

class UpdateWorker
  include Sidekiq::Worker

  # require 'pry-remote'

  # The only reason this is in a worker is because I don't want to rely on how
  # quickly Github's API can update. This system allows retries until it finds the
  # updated data. The cost is one db hit, one extra github API request and a
  # bit more complexity.
  def perform(book_id)
    book = Book.find(book_id)
    token = User.find(book.user_id).token
    github = Octokit::Client.new :access_token => token

    repo_id = github.repository(book.gh_full_name).id
    data = { "repo_id" => repo_id, "github_id" => github.user.id }

    # I can't use "create_commit_hook()" from here because it's an instance method,
    # not a class method. Options are: 1) Do this step via an http request
    # (thus starting a new instance), 2) Convert it into a class method, or 3)
    # re-implement the function steps here. I feel like option 1 is the right
    # choice for now.

    response = RestClient::Request.new(
      :method => :post,
      :url => BITBOOKS_ROOT + "/books/#{book_id}/repo-id",
      :user => 'bitbooks',
      :password => BITBOOKS_PASS,
      :payload => { :data => data },
      :headers => { :content_type => :json, :accept => :json }
    ).execute

  end
end

######################################
# Routing Calls
######################################

# Define pages (GET requests with template responses) at specific URLs

# Home page
get "/" do
  erb :"templates/index", :locals => {:client_id => CLIENT_ID}
end

# About
get "/about" do
  erb :"templates/about"
end

# @todo: one day, set this up as another way to monitor jobs in the queue.
# get "/admin/activity" do
#  stats = Sidekiq::Stats.new
#  @failed = stats.failed
#  @processed = stats.processed
#  @messages = $redis.lrange('sinkiq-example-messages', 0, -1)
#  erb :"templates/sidekiq"
# end

# Styleguide
get "/styleguide" do
  erb :"templates/styleguide"
end

get "/docs/book-repository" do
  erb :"templates/docs/book-repository"
end

# Logout link
get '/logout' do
  session.clear
  redirect "/"
end

# User landing page
get "/my-books" do
  if !authenticated?; authenticate!; end

  user = User.find_by(github_id: client.user.id)

  # Get all books created by the current user, and if there are none,
  # redirect to the "new book" page
  @books = Book.where("user_id = ?", user.id)
  if @books.empty?
    redirect "/books/new"
  end

  # End test
  erb :"templates/my_books"
end

# A form for adding a new book.
get "/books/new" do
  if !authenticated?; authenticate!; end

  # Get data for this page.
  @repos = get_qualifying_repos
  @title = "Add a New Book"
  @book = Book.new
  @username = client.user.login
  erb :"templates/new-book"
end

# A form for editing book details.
get "/books/:id" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Get data for this page.
  user = User.find_by(github_id: client.user.id)
  @book = Book.find(params[:id])
  @title = "Change Book Details"

  # Only the creator of this book should be able to see this page.
  if @book.user_id != user.id
    halt 404
  end

  erb :"templates/edit-book"
end

# A form for adding a domain to a book.
get "/books/:id/domain" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Get data for this page.
  user = User.find_by(github_id: client.user.id)
  @book = Book.find(params[:id])
  @title = "Add a Custom Domain"

  # Only the creator of this book should be able to see this page.
  if @book.user_id != user.id
    halt 404
  end

  erb :"templates/domain"
end

# 404 Page Not Found.
not_found do
  status 404
  erb :"templates/404"
end


# Callback URL for Github Authentication. This gets a github oauth token for me
# for use in acquiring API data. It runs every time a person uses "Log in
# with Github". It's a bit manual and could be replaced with
# https://github.com/atmos/sinatra_auth_github, (or, perhaps, Oauth2) but it works well for now.
get '/callback' do
  # Get temporary GitHub code...
  session_code = request.env['rack.request.query_hash']['code']

  # ... and POST it back to GitHub
  result = RestClient.post('https://github.com/login/oauth/access_token',
                          {:client_id => CLIENT_ID,
                           :client_secret => CLIENT_SECRET,
                           :code => session_code},
                           :accept => :json)
  # example result:
  # { "access_token":"xxasdfasdf234234123dvadsfasdfas",
  #   "token_type":"bearer",
  #   "scope":"user:email"
  # }

  token = JSON.parse(result)['access_token']

  # Uncomment the line below to get the access token (for fiddling with octokit in tux)
  # flash[:info] = token

  # If a new user hasn't already been created, then create one now.
  github = Octokit::Client.new :access_token => token
  session[:github_id] = github.user.id

  # We pass the github object because we don't know if the token has changed
  # or not, and we need to be able to make db updates.
  if !User.exists?(github_id: github.user.id)
    create_new_user(github)
  else
    update_user_info(github)
  end

  # As soon as anybody authenticates, we kick them to "my-books".
  redirect '/my-books'
end

# Define other API behaviors
#
# Reminder: Restful HTTP Verbs
# - GET, (list records)
# - PUT, (update records)
# - POST, (create records)
# - DELETE, (delete records)
#
# (see also http://stackoverflow.com/questions/2001773
#  and https://blog.apigee.com/detail/restful_api_design_nouns_are_good_verbs_are_bad)
#
# Our "records" noun will be "books".

# The New Book form sends a POST request (storing data) here
# where we try to create the book it sent in its params hash.
# If successful, redirect to "my-books". Otherwise, render the "posts/new"
# template where the @post object will have the incomplete data that the
# user can modify and resubmit.
post "/books" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Get relevant data.
  username = client.user.login
  current_user = User.find_by(github_id: client.user.id)
  full_name = params[:book]["gh_full_name"]
  cloned = (params[:book]["source"] == 'cloned')

  # If this isn't a real repository, or the repository doesn't belong to this
  # user, cancel the request. This also prevents "collaborators" from making
  # a book-site for a repo that technically isn't theirs.
  # Note: The only exception is cloned books. Those can pass through.
  if (!client.repository?(full_name) || username != full_name.split('/')[0]) && !cloned
    flash[:warning] = "This book could not be created because you do not have access to this Github repository."
    redirect "/books/new"
  else
    # Assign values for cloned books.
    full_name = params[:book]["gh_full_name"] = username + '/starter-book' if cloned
    params[:book].delete("source") # No need to store this.

    # Prevent back-button duplicate book submission.
    if Book.exists?(:gh_full_name => full_name)
      # They are trying to recreate a book already in our database.
      flash[:warning] = "This book could not be created because there is already a book for this Github repository."
      redirect "/books/new"
    end

    # ID's increment automatically, so if they tried to post a different ID for this book, delete it.
    if params[:book]["id"]
      params[:book].delete("id")
    end

    # Assign any data we want in our database to our POST params. We save them to
    # the params (instead of to the book object), in order to overwrite any erroneous
    # post data that anybody could inject:
    params[:book]["github_id"] = client.repository(full_name).id unless cloned # The github repo ID
    params[:book]["user_id"] = current_user.id
    params[:book]["github_url"] = "https://github.com/" + full_name
    params[:book]["github_pages_url"] = "http://" + username.downcase + ".github.io/" + full_name.split('/')[1]
    params[:book]["created_at"] = Time.now
    params[:book]["updated_at"] = Time.now

    # License Fields
    license_choice = params[:book]["license"]
    unless license_choice.nil? || license_choice == "other"
      license_info = get_license_info(license_choice)
      params[:book]["license_name"] = license_info[:name]
      params[:book]["license_url"] = license_info[:url]
    end

    # Create book object and save it to the database.
    @book = Book.new(params[:book])

    if @book.save
      # Queue jobs for the book.
      flash[:success] = "Your site is being built! It may take a few minutes before it is available."

      if cloned
        CopyWorker.perform_async(@book.id)
      else
        BuildWorker.perform_async(@book.id)
        create_commit_hook(@book.id)
      end

      redirect "/my-books"
    else
      flash[:warning] = "Oops. Something went wrong and your site was not created. Please try again."
      redirect "/books/new"
    end
  end
end

# The Edit Book form sends a PUT request (updating data) here.
# If the book is updated successfully, redirect to "my-books". Otherwise,
# render the edit form again with the failed @post object still in memory
# so they can retry.
#
# The Domain form can also send a request here to update a person's domain to
# a custom one of their choosing.
put "/books/:id" do
  # Only authenticated users can make updates.
  if !authenticated?; authenticate!; end

  # Get relevant book data.
  user = User.find_by(github_id: client.user.id)
  @book = Book.find(params[:id])

  # Users can only update their own books.
  if @book.user_id != user.id
    flash[:warning] = "Your changes could not be made because you do not have access to this book."
    redirect "/my-books"
  end

  # Don't allow users to update "protected" properties, including:
  protected_properties = ["id", "gh_full_name", "github_pages_url", "github_url", "created_at", "updated_at", "user_id", "github_id"]
  protected_properties.each do |property|
    if params[:book][property]
      params[:book].delete(property)
    end
  end

  # Update any other changed data.
  params[:book]["updated_at"] = Time.now
  # Update license fields.
  license_choice = params[:book]["license"]
  unless license_choice.nil? || license_choice.downcase == "other"
    license_info = get_license_info(license_choice)
    params[:book]["license_name"] = license_info[:name]
    params[:book]["license_url"] = license_info[:url]
  end

  if @book.update_attributes(params[:book])
    # Queue this book rebuild with sidekiq.
    BuildWorker.perform_async(@book.id)

    flash[:success] = "Your changes have been made. It may take a few minutes before they are visible online."
    redirect "/my-books"
  else
    flash[:warning] = "Oops. Something went wrong. Try again."
    redirect "/books/#{params[:id]}/edit"
  end
end

# Expose an endpoint for post-commit hooks to trigger site builds.
post "/books/:id/build" do

  # Authenticate the request, by rebuilding the sha locally, and seeing if it matches.
  # For more info, see: https://developer.github.com/v3/repos/hooks/#example, and
  # https://github.com/github/github-services/blob/f3bb3dd780feb6318c42b2db064ed6d481b70a1f/lib/service/http_helper.rb#L77
  headers = request.instance_variable_get("@env")
  header_sha = headers['HTTP_X_HUB_SIGNATURE'].sub("sha1=", "")
  body = request.body.read
  local_sha = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha1'), HOOK_SECRET, body)

  if header_sha != local_sha
    status 401 # unauthorized
  else
    push = JSON.parse(body)

    # Github's initial 'ping' request (which is sent when a commit hook is created)
    # chokes if we try to build a book with data it doesn't contain, so we only do
    # a build if there is a 'repository' key. Also, to prevent infinite build loops,
    # we only do a build when a change is made to the master branch.
    if push.key?("repository") && push["ref"] == 'refs/heads/master'
      BuildWorker.perform_async(params[:id])
    end
  end
end

# I'm using a new route instead of 'put "/books/:id"'' because 1) the other
# route has baked in validation logic (for better or worse), 2) this is for
# internal requests only, and 3) this specific request is needed often. The
# path naming I went with is described here:
# http://williamdurand.fr/2014/02/14/please-do-not-patch-like-an-idiot/
post "/books/:id/repo-id" do
  protected!
  github_id = session[:github_id] = params[:data][:github_id]
  book = Book.find(params[:id])
  book.update(github_id: github_id)
  create_commit_hook(params[:id])
end

# Reserving this GET request route for returning a list of books via JSON,
# @todo Set this up to return JSON, for making a javascript powered
# single page app.
#
# get "/books/:id" do
#
# end

# Deletes the book with this ID and redirects to homepage.
delete "/books/:id" do
  # Only authenticated users can delete books.
  if !authenticated?; authenticate!; end

  # Get relevant book data.
  user = User.find_by(github_id: client.user.id)
  book = Book.find(params[:id])

  # Users can only delete their own books.
  if book.user_id != user.id
    flash[:warning] = "The site could not be deleted because you do not have access to this book."
    redirect "/my-books"
  end

  # Delete the site.
  delete_branch(book.gh_full_name)
  delete_commit_hook(book.id)
  book.destroy

  flash[:success] = "Your book site has been deleted."
  redirect "/my-books"
end

######################################
# Define Methods for use in our app
######################################

def create_new_user(github)
  user = User.new
  user.github_id = github.user.id
  user.username = github.user.login
  user.email = github.user.email
  user.created_at = Time.now
  user.updated_at = Time.now
  user.token = github.access_token
  user.save
  flash[:info] = "Hi friend! Let's start you out by creating your first book."
end

def update_user_info(github)
  user = User.find_by(github_id: session[:github_id])
  user.username = github.user.login unless user.username == github.user.login
  user.email = github.user.email unless user.email == github.user.email
  user.token = github.access_token unless user.token == github.access_token
  user.updated_at = Time.now
  user.save
end

def create_commit_hook(book_id)
  if client.scopes.include?("admin:repo_hook") || client.scopes.include?("write:repo_hook")
    book = Book.find(book_id)
    config =  {
                :url =>  BITBOOKS_ROOT + '/books/' + book_id.to_s + '/build',
                :content_type => 'json',
                :secret => HOOK_SECRET
              }
    options = {
                :name => 'web',
                :events => ['push'],
                :active => true
              }
    begin
      hook = client.create_hook(book.gh_full_name, 'bitbooks', config, options)
      book.update(hook_id: hook.id)
      flash[:success] = 'Your site will be updated automatically, with each new commit.'
      return true
    rescue Octokit::UnprocessableEntity # Commit hook already exists
      flash[:info] = 'Your site will not be auto-updated with each commit.'
      return false
    rescue Octokit::NotFound # Page not found (likely, the repo doesn't exist)
      flash[:info] = 'Your site will not be auto-updated with each commit.'
      return false
    end
  else
    return false
  end
end

def delete_branch(github_full_name)
  if client.scopes.include?("public_repo") || client.scopes.include?("repo")
    client.delete_branch(github_full_name, 'gh-pages') if branch_exists?('gh-pages', github_full_name)
  end
end

# @todo: See if this is helpful it's from copy-to, but I haven't integrated it yet.
def repo_exists?(gh_full_name)
  client.repository gh_full_name
rescue Octokit::NotFound
  false
end

# This function is a more atomic way to delete hooks, but it hits the database
# two more times.
#
# @return [Boolean] True if hook removed & record updated, false if otherwise.
def delete_commit_hook(book_id)
  book = Book.find(book_id)
  if repo_exists?(book.gh_full_name) && client.scopes.include?("admin:repo_hook")
    # No need for error handling because this function returns false if it fails.
    removed = client.remove_hook(book.gh_full_name, book.hook_id)
    if removed
      book.update(hook_id: nil)
    else
      return false
    end
  end
end

# Get License info from token.
def get_license_info(token)
  licenses = Hash.new
  licenses["cc-by"] = { :name => 'Attribution', :url => 'https://creativecommons.org/licenses/by/4.0' }
  licenses["cc-by-nd"] = { :name => 'Attribution-NoDerivs', :url => 'https://creativecommons.org/licenses/by-nd/4.0' }
  licenses["cc-by-sa"] = { :name => 'Attribution-ShareAlike', :url => 'https://creativecommons.org/licenses/by-sa/4.0' }
  licenses["cc-by-nc"] = { :name => 'Attribution-NonCommercial', :url => 'https://creativecommons.org/licenses/by-nc/4.0' }
  licenses["cc-by-nc-sa"] = { :name => 'Attribution-NonCommercial-ShareAlike', :url => 'https://creativecommons.org/licenses/by-nc-sa/4.0' }
  licenses["cc-by-nc-nd"] = { :name => 'Attribution-NonCommercial-NoDerivs', :url => 'https://creativecommons.org/licenses/by-nc-nd/4.0' }
  license_info = licenses[token]
end


# This is the main function for interfacing with the Github API. Unfortunately,
# I had to make it more verbose in order to handle unauthorize errors (using
# validate_credentials()... the rescue block just didn't seem to work). Maybe
# some day I can get it back to the simplicity of "app_client" below it.
def client
  client_object_exists = (defined?(@client) != nil)
  if client_object_exists
    return @client
  else
    user = User.find_by(github_id: session[:github_id])
    if Octokit.validate_credentials({ :access_token => user.token })
      # Auto paginate to prevent repo-list truncation on the books/new page. This may
      # hurt performance, so keep an eye on it.
      @client = Octokit::Client.new :access_token => user.token, :auto_paginate => true
    else
      authenticate!
    end
  end
end

# For generic API requests (provides higher rate-limits than when using user-token based calls).
def app_client
  @app_client ||= Octokit::Client.new :client_id => GH_BASIC_CLIENT_ID, :client_secret => GH_BASIC_SECRET_ID
end

def branch_exists?(branch_name, repo_full_name)
  client.branch(repo_full_name, branch_name).present?
rescue Octokit::NotFound
  false
end

# Get all repos that would qualify for a new book-site.
def get_qualifying_repos
  if !authenticated?
    authenticate!
  end

  # Get Github data.
  repos = client.repositories
  username = client.user.login

  # Compile a list of repositories for projecs that we've already used.
  user = User.find_by(github_id: client.user.id)
  used_repos = Array.new
  my_books = Book.where("user_id = ?", user.id)
  [*my_books].each do |book|
    used_repos << book[:gh_full_name]
  end

  # Identify the names claimed for github user/organization pages. There may
  # be a better way to remove them than string detection, but I'll use it for
  # now, since it looks like that's what github uses and I don't know beter.
  name_match_1 = username + '.github.io' #=> octocat.github.io
  name_match_2 = username + '.github.com' #=> octocat.github.com

  # Iterate through our array of github repos and delete ones from the list
  # that don't qualify for a new book-site.
  repos.delete_if do |repo|
    # Remove this repo if it matches the name for a user/org page project.
    if repo.name == name_match_1 || repo.name == name_match_2
      true
    # Remove this repo if it has already been used for a book.
    elsif used_repos.include? repo.full_name
      true
    # Remove this repo if it doesn't belong to this user. This is designed to
    # remove repos you are a "collaborator" on.
    elsif username != repo.full_name.split('/')[0]
      true
    else
      # This repo is good... don't delete it.

      # Add a gh-pages flag method (and value) to each repo, for later use.
      repo.class.module_eval { attr_accessor :has_gh_pages? }
      if branch_exists?('gh-pages', repo.full_name)
        repo.has_gh_pages = true
      else
        repo.has_gh_pages = false
      end

      false # End loop. Return false says "don't delete the repo".
    end
  end

  return repos
end


######################################
# Define Helpers
######################################

# These helpers can be used in my layouts or templates
helpers do
  # If @title is assigned, add it to the page's title.
  def title
    if @title
      "#{@title} -- My Books"
    else
      "My Books"
    end
  end

  # A tiny helper for deleting a book.
  # @todo: This can be replaced and put inline in the template (Less code is better)
  # See: http://www.sinatrarb.com/faq.html#partials
  def delete_book(book_id)
    erb :"partials/_delete_book", locals: { book_id: book_id }
  end

  # Provide the Log-in or Log-out link, depending on the current login status.
  def login_link
    if !authenticated?
      link = '<li><a href="https://github.com/login/oauth/authorize?scope=public_repo,admin:repo_hook&client_id=' + CLIENT_ID + '">Log in with Github</a></li>'
    else
      link = '<li><a href="/logout">Log out</a></li>'
    end
  end

  # Github helpers getting repo-specific data
  def get_repo_name(full_name)
    repo_name = client.repository(full_name).name
  rescue Octokit::NotFound
    "being cloned..."
  end

  # Get github project star count
  def get_star_count(full_name)
    star_count = client.repository(full_name).stargazers_count
  rescue Octokit::NotFound
    nil
  end

  # Get github project issue count
  def get_issue_count(full_name)
    issue_count = client.repository(full_name).open_issues_count
  rescue Octokit::NotFound
    nil
  end

  # Get github project forks count
  def get_fork_count(full_name)
    forks_count = client.repository(full_name).forks_count
  rescue Octokit::NotFound
    nil
  end

  # Get github project pull request count
  def get_pull_request_count(full_name)
    pull_request_count = client.pull_requests(full_name, :state => 'open').length
  rescue Octokit::NotFound
    nil
  end

  # A helper for embedding SVG images
  def inline_svg(path)
    file = File.open("public/images/#{path}", "rb")
    file.read
  end

  # A helper for escaping HTML when printing data to the page.
  include Rack::Utils
  alias_method :h, :escape_html

  # Return markup for each of the Creative Common Licence Logos.
  def license_link(book)
    case book.license
    when nil
      return 'None<a class="btn btn-mini" href="/books/' + book.id.to_s + '/edit#license">Choose a License</a>'
    when "cc-by"
      return '<a href="' + book.license_url + '" class="linked-icon" title="' + book.license_name + '"><span class="icon-cc"></span><span class="icon-cc-by"></span><span class="cc-title">' + book.license_name + '</span></a>'
    when "cc-by-nd"
      return '<a href="' + book.license_url + '" class="linked-icon" title="' + book.license_name + '"><span class="icon-cc"></span><span class="icon-cc-by"></span><span class="icon-cc-nd"></span><span class="cc-title">' + book.license_name + '</span></a>'
    when "cc-by-sa"
      return '<a href="' + book.license_url + '" class="linked-icon" title="' + book.license_name + '"><span class="icon-cc"></span><span class="icon-cc-by"></span><span class="icon-cc-sa"></span><span class="cc-title">' + book.license_name + '</span></a>'
    when "cc-by-nc"
      return '<a href="' + book.license_url + '" class="linked-icon" title="' + book.license_name + '"><span class="icon-cc"></span><span class="icon-cc-by"></span><span class="icon-cc-nc"></span><span class="cc-title">' + book.license_name + '</span></a>'
    when "cc-by-nc-sa"
      return '<a href="' + book.license_url + '" class="linked-icon" title="' + book.license_name + '"><span class="icon-cc"></span><span class="icon-cc-by"></span><span class="icon-cc-nc"></span><span class="icon-cc-sa"></span><span class="cc-title">' + book.license_name + '</span></a>'
    when "cc-by-nc-nd"
      return '<a href="' + book.license_url + '" class="linked-icon" title="' + book.license_name + '"><span class="icon-cc"></span><span class="icon-cc-by"></span><span class="icon-cc-nc"></span><span class="icon-cc-nd"></span><span class="cc-title">' + book.license_name + '</span></a>'
    else
      # This is an "Other" license.
      # @todo, I could simplify the schema a bit by getting rid of the "Other license" field and just
      # allowing their custom license to be placed in the "license" field.
      return '<a href="' + Rack::Utils.escape_html(book.license_url) + '" title="' + book.license_name + '">' + Rack::Utils.escape_html(book.license_name) + '</a>'
    end
  end

  # Returns TRUE if the domain provided is custom and FALSE if it is not.
  def domain_is_custom(book)
    if book.domain.nil? || book.domain.empty?
      # Domain is not custom.
      false
    else
      # Domain is custom.
      true
    end
  end

  # This logic could be done in templates but we call it a lot, so this is more concise.
  def link_to_book(book)
    # If a custom domain hasn't been specified, return the default github url.
    if book.domain.nil? || book.domain.empty?
      book.github_pages_url
    else
      # A custom domain has been specified.
      return 'http://' + Rack::Utils.escape_html(book.domain)
    end
  end

end