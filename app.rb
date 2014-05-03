# app.rb
# The guts of our Sinatra app

require "sinatra"
require "sinatra/activerecord"
require 'sinatra/flash'
require 'rest-client'
require 'json'
require 'octokit'



# for pretty print debugging
require 'pp'

# Needed for making persistant messages with the sinatra/flash gem, and for
# preserving github auth tokens across sessions.
enable :sessions

# Set up the database
set :database, "sqlite3:///blog.db"
# This is our database object, Book
#
# I can query it with the Active Record Querying Interface (http://guides.rubyonrails.org/active_record_querying.html)
#
# Examples:
# Book.count #=> Counts the number of records in the books table
# Book.All #=> Returns all books. Equivalent to SELECT * from books;
#
class Book < ActiveRecord::Base
end


######################################
# Github Auth
#
# Based on this awesome tutorial:
# http://developer.github.com/guides/basics-of-authentication/
######################################

CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']

def authenticated?
  session[:access_token]
end

def authenticate!
  message = 'Please <a href="https://github.com/login/oauth/authorize?scope=public_repo&client_id=' + CLIENT_ID + '">login with Github</a> to continue.'
  flash[:info] = message
  redirect '/'
end

######################################
# Async Queue setup
# Example: https://github.com/mperham/sidekiq/blob/master/examples/sinkiq.rb
######################################

# For this to work ake sure you have Sinatra installed, and redis installed
# (see http://stackoverflow.com/a/13635955/1154642). Start redis with:
#
#   redis-server
#
# then start sidekiq with
#
#   bundle exec sidekiq -r ./app.rb
#

$redis = Redis.new

class SinatraWorker
  include Sidekiq::Worker

  # Define the action that we want the worker to do.
  # @todo: Password protect this request (stored as an ENV variable)
  def perform(book_id)
    # We are sending the book's unique data (the contents of book.yml)
    # over in a post request. This will be used to build the book.
    book_info = Book.find(book_id)
    response = RestClient.post("127.0.0.1:4567/build", {:data => book_info.to_json}, {:content_type => :json, :accept => :json })

    # Throw in a message, for testing purposes.
    $redis.lpush("sinkiq-example-messages", response)
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

# Sidekiq example
 get "/sidekiq-test" do
  #binding.remote_pry
  stats = Sidekiq::Stats.new
  @failed = stats.failed
  @processed = stats.processed
  @messages = $redis.lrange('sinkiq-example-messages', 0, -1)
  erb :"templates/sidekiq"
end

post '/sidekiq-test' do
  SinatraWorker.perform_async params[:msg]
  redirect to('/sidekiq-test')
end

# Styleguide
get "/styleguide" do
  erb :"templates/styleguide"
end

# Logout link
get '/logout' do
  session.clear
  redirect "/"
end

# User landing page
get "/my-books" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Get github data needed for this page.
  client = Octokit::Client.new :access_token => session[:access_token]
  @gh_data = client

  # Get books created by the current user.
  @books = Book.where("username = ?", client.user.login)

  # If this user has no books, send them to the new-book page. (untested)
  if @books.empty?
    flash[:info] = "Hi friend! Let's start you out by creating your first book."
    redirect "/books/new"
  end

  # End test
  erb :"templates/my_books"
end

# A form for adding a new book.
get "/books/new" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Check if there is already a gh-pages branch. If so, warn the user that this will
  # overwrite the contents of their gh-pages branch, and have them confirm that they're
  # ok with that.
  # @todo, add this check. Actually, I think I want to do this client-side, before the post.

  # Get github repo data, and other data for this page.
  client = Octokit::Client.new :access_token => session[:access_token]
  @repos = get_qualifying_repos(client)
  @title = "Add a New Book"
  @book = Book.new
  erb :"templates/new-book"
end

# A form for editing book details.
get "/books/:id/edit" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Get github repo data, and other data for this page.
  client = Octokit::Client.new :access_token => session[:access_token]
  gh_username = client.user.login
  @book = Book.find(params[:id])
  @title = "Change Book Details"

  # Only the creator of this book should be able to see this page.
  if @book.username != gh_username
    halt 404
  end

  erb :"templates/edit-book"
end

# A form for adding a domain to a book.
get "/books/:id/domain" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  # Get github data, and other data for this page.
  client = Octokit::Client.new :access_token => session[:access_token]
  gh_username = client.user.login
  @book = Book.find(params[:id])
  @title = "Add a Custom Domain"

  # Only the creator of this book should be able to see this page.
  if @book.username != gh_username
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
# for use in acquiring API data. It's a bit manual and could be replaced with 
# https://github.com/atmos/sinatra_auth_github, but it works well for now.
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

  session[:access_token] = JSON.parse(result)['access_token']

  # Uncomment the line below to get the access token (for fiddling with octokit in tux)
  # flash[:info] = session[:access_token]

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
# (see also http://stackoverflow.com/questions/2001773)
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

  # Get data from github and the post request for processing.
  client = Octokit::Client.new :access_token => session[:access_token]
  username = client.user.login
  full_name = params[:book]["gh_full_name"]

  # If this isn't a real repository, or the repository doesn't belong to this
  # user, cancel the request. This also prevents "collaborators" from making
  # a book-site for a repo that technically isn't theirs.
  if !client.repository?(full_name) || username != full_name.split('/')[0]
    flash[:warning] = "This book could not be created because you do not have access to this Github repository."
    redirect "/books/new"
  else
    # Continue with book creation.
    name = client.repository(full_name).name

    # Check our Books database to make sure this Book-site doesn't already exist
    # (back button duplicate book submission).
    #
    # If we can't find a book in our database by this name...
    if Book.find_by(gh_full_name: full_name).nil?
      # This record doesn't exist. Good.
    else
      # They are trying to recreate a book already in our database. Let's prevent that.
      flash[:warning] = "This book could not be created because there is already a book for this Github repository."
      redirect "/books/new"
    end

    # ID's increment automatically, so if they tried to post a different ID for this book, delete it.
    if params[:book]["id"]
      params[:book].delete("id")
    end

    # Assign any data we want in our database to our POST params:
    params[:book]["username"] = username
    params[:book]["github_url"] = "https://github.com/" + full_name
    params[:book]["github_pages_url"] = "http://" + username.downcase + ".github.io/" + name
    # License Fields
    license_choice = params[:book]["license"]
    unless license_choice.nil? || license_choice == "other"
      license_info = get_license_info(license_choice)
      params[:book]["license_name"] = license_info[:name]
      params[:book]["license_url"] = license_info[:url]
    end

    ### Clone example book, if that option was chosen ###

    # Create book object and save it to the database.
    @book = Book.new(params[:book])

    if @book.save
      # Queue this book build with sidekiq.
      SinatraWorker.perform_async(@book.id)

      flash[:success] = "Your site has been created."
      redirect "/my-books"
    else
      flash[:warning] = "Oops. Something went wrong and your book was not created. Please try again."
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

  # Get relevant book and github data.
  client = Octokit::Client.new :access_token => session[:access_token]
  gh_username = client.user.login
  @book = Book.find(params[:id])

  # Users can only update their own books.
  if @book.username != gh_username
    flash[:warning] = "Your changes could not be made because you do not have access to this book."
    redirect "/my-books"
  end

  # Don't allow users to update "protected" properties, including:
  # - id
  # - username
  # - gh_full_name
  # - github_pages_url
  # - github_url
  protected_props = ["id","username", "gh_full_name", "github_pages_url", "github_url"]
  protected_props.each do |property|
    # If this property is in their params array, delete it out.
    if params[:book][property]
      params[:book].delete(property)
    end
  end

  # Update license fields.
  license_choice = params[:book]["license"]
  unless license_choice.nil? || license_choice.downcase == "other"
    license_info = get_license_info(license_choice)
    params[:book]["license_name"] = license_info[:name]
    params[:book]["license_url"] = license_info[:url]
  end

  if @book.update_attributes(params[:book])
    # Queue this book rebuild with sidekiq.
    SinatraWorker.perform_async(@book.id)

    flash[:success] = "Your changes have been made."
    redirect "/my-books"
  else
    flash[:warning] = "Oops. Something went wrong. Try again."
    redirect "/books/#{params[:id]}/edit"
  end
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

  # Get relevant book and github data.
  client = Octokit::Client.new :access_token => session[:access_token]
  gh_username = client.user.login
  @book = Book.find(params[:id])

  # Users can only delete their own books.
  if @book.username != gh_username
    flash[:warning] = "The site could not be deleted because you do not have access to this book."
    redirect "/my-books"
  end

  # Delete the database record for the book.
  @book.destroy
  flash[:success] = "Bye Bye. Your book site has been deleted."
  redirect "/my-books"
end

######################################
# Define Methods for use in our app
######################################

# This is a test of octokit.
def get_octokit()
  if !authenticated?
    authenticate!
  else
    client = Octokit::Client.new :access_token => session[:access_token]

    # Create a hash for collecting our example data.
    data = Hash.new
    data[:login] = client.user.login # => This should return the github username.

    # Instantiate arrays for storing repo data.
    data[:repo_id] = Array.new
    data[:repo_name] = Array.new
    data[:repo_path] = Array.new

    # Loop through repositories and collect repo data.
    client.repositories.each do |repo|
      data[:repo_id] << repo.id
      data[:repo_name] << repo.name
      data[:repo_path] << repo.full_name
      # You can see all repo methods by printing repo.methods
    end
    return data
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

# Get all repos that would qualify for a new book-site.
def get_qualifying_repos(client)
  if !authenticated?
    authenticate!
  end
  if !client
    client = Octokit::Client.new :access_token => session[:access_token]
  end

  username = client.user.login

  # Create a new variable containing all repository data.
  repos = client.repositories

  # Compile a list of repositories for projecs that we've already used.
  used_repos = Array.new
  Book.all.each do |book|
    used_repos << book[:gh_full_name]
  end

  # Identify the names claimed for github user/organization pages. There may
  # be a better way to remove them than string detection, but I'll use it for
  # now, since it looks like that's what github uses and I don't know beter.
  name_match_1 = client.user.login + '.github.io' #=> octocat.github.io
  name_match_2 = client.user.login + '.github.com' #=> octocat.github.com

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
      false
    end
  end

  return repos
end


# This is a helper function for getting API data via REST api calls. A little
# bit more manual than using octokit. I'll leave it here until I get a more 
# elegant octokit-based one set up.
def get_github_data()
  if !authenticated?
    authenticate!
  else
    access_token = session[:access_token]
    scopes = []

    begin
      # Fetch information via the API. The data returned depends on the scope of
      # access requested in the original login parameters. Currently, this
      # returns all user data, but what we really need it for is to check and
      # see that the token isn't revoked, and to get scope information for more
      # specific requests from the header. For information about scopes see 
      # http://developer.github.com/v3/oauth/#scopes
      auth_result = RestClient.get('https://api.github.com/user',
                                   {:params => {:access_token => access_token},
                                    :accept => :json})
    rescue => e
      # Request didn't succeed because the token was revoked so we
      # invalidate the token stored in the session and render the
      # index page so that the user can start the OAuth flow again
      session[:access_token] = nil
      return authenticate!
    end

    # The request succeeded, so we check the list of current scopes
    if auth_result.headers.include? :x_oauth_scopes
      scopes = auth_result.headers[:x_oauth_scopes].split(', ')
    end

    auth_result = JSON.parse(auth_result)

    # Uncomment this line to return a list of approved scopes.
    # return scopes
    # Uncomment this line to return a json dump of all available data.
    # return auth_result

    # @todo: Change this hardcoded user:email scope check and get request
    #        to one powered by parameters passed into the method.
    if scopes.include? 'user:email'
      auth_result['private_emails'] =
        JSON.parse(RestClient.get('https://api.github.com/user/emails',
                       {:params => {:access_token => access_token},
                        :accept => :json}))
    end
  end
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
      link = '<li><a href="https://github.com/login/oauth/authorize?scope=public_repo&client_id=' + CLIENT_ID + '">Log in</a></li>'
    else
      link = '<li><a href="/logout">Log out</a></li>'
    end
  end

  # Github helpers getting repo-specific data
  # Get github project name
  # @todo: see if I can refactor this such that I don't have to reconnect to the
  # client for every helper. That's got to be a drag on performance.
  def get_repo_name(full_name, client = nil)
    if !client
      client = Octokit::Client.new :access_token => session[:access_token]
    end
    repo_name = client.repository(full_name).name
  end

  # Get github project star count
  def get_star_count(full_name, client = nil)
    if !client
      client = Octokit::Client.new :access_token => session[:access_token]
    end
    star_count = client.repository(full_name).stargazers_count
  end

  # Get github project issue count
  def get_issue_count(full_name, client = nil)
    if !client
      client = Octokit::Client.new :access_token => session[:access_token]
    end
    issue_count = client.repository(full_name).open_issues_count
  end

  # Get github project forks count
  def get_fork_count(full_name, client = nil)
    if !client
      client = Octokit::Client.new :access_token => session[:access_token]
    end
    forks_count = client.repository(full_name).forks_count
  end

  # Get github project pull request count
  def get_pull_request_count(full_name, client = nil)
    if !client
      client = Octokit::Client.new :access_token => session[:access_token]
    end
    pull_request_count = client.pull_requests(full_name, :state => 'open').length
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
      # Needed to escape double quotes because I want attributes with double quotes as well as interpolate the book value.
      return 'None<a class="btn btn-mini" href="/books/' + book.id + '/edit#license">Choose a License</a>'
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