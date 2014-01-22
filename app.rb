# app.rb
# The guts of our Sinatra app

require "sinatra"
require "sinatra/activerecord"
require 'sinatra/flash'
require 'rest-client'
require 'json'

# for pretty print debugging
require 'pp'

# Needed for making persistant messages with the sinatra/flash gem.
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

# I don't think this line is needed since we have sessions enabled above.
# use Rack::Session::Cookie, :secret => rand.to_s()

def authenticated?
  session[:access_token]
end

def authenticate!
  message = 'Please <a href="https://github.com/login/oauth/authorize?scope=user:email,public_repo&client_id=' + CLIENT_ID + '">login with Github</a> to continue.'
  flash[:info] = message
  redirect '/'
end

######################################
# Routing Calls
######################################

# Define pages (GET requests with template responses) at specific URLs

# Home page
get "/" do
  erb :"templates/index", :locals => {:client_id => CLIENT_ID}
end

# User dashboard
get "/dashboard" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  @books = unserialize_data(Book.all)
  # Testing get_github_data()
  flash[:success] = get_github_data()

  # End test
  erb :"templates/dashboard"
end

# Styleguide
get "/styleguide" do
  erb :"templates/styleguide"
end

# A form for adding a new book
get "/books/new" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  @title = "Add a New Book"
  @book = Book.new
  erb :"templates/new-book"
end

# A form for editing book details
get "/books/:id/edit" do
  # Access to this page requires authentication.
  if !authenticated?; authenticate!; end

  @book = Book.find(params[:id])
  @title = "Change Book Details"
  erb :"templates/edit-book"
end

# 404 Page Not Found
not_found do
  status 404
  'Oops. Page not Found'
  erb :"templates/404"
end

# Callback URL for Github Authentication
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

  # As soon as anybody authenticates, we kick them to the dashboard.
  redirect '/dashboard'
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
# If successful, redirect to the dashboard. Otherwise, render the "posts/new"
# template where the @post object will have the incomplete data that the 
# user can modify and resubmit.
post "/books" do

  # Get the file upload data for processing.
  # @todo: This image validation needs to happen on the Edit book form as well.
  pp params

  # Perform validation on the file upload, including:
  # [X] HTML5 clientside filtering for acception mime types
  # [ ] Clientside valideation
  #     [X] Warning message
  #     [ ] Prevent submission
  # [X] Check against mime type whitelist
  # [X] Check against file extension whitelist
  # Also, for extra protection (perhaps not MVP)
  # [ ] Resize the image (on the server) and strip metadata (then delete the original image)
  #     - We need to do this anyway, to prevent monstrous images from being uploaded.
  # [ ] Rename the file

  if params[:book]['cover_image']
    # The typical image upload object will look something like this:
    # {
    #   "cover_image" => {
    #     :filename=>"cat.png"
    #     :name => "book[cover_image]",
    #     :type => "image/png",
    #     :tempfile => #<File:/var/folders/3n/3asd/-Tmp-/RackMultipart201-1476-nfw2-0>,
    #     :head =>  "Content-Disposition: form-data;
    #                name=\"myfile\";
    #                filename=\"cat.png\"\r\n
    #                Content-Type: image/png\r\n",
    #   }
    # }   

    # A cover image has been uploaded. Perform serverside validation.
    file_hash = params[:book]['cover_image']
    # Only supporting uploads with mime type of GIF, JPEG(s), and PNG.
    mime_whitelist = ['image/gif', 'image/jpeg', 'image/pjpeg', 'image/png']
    if !mime_whitelist.include? file_hash[:type]
      flash[:warning] = "Oops. It looks like your image wasn't a gif, jpeg, or png. Please choose a supported image type."
      redirect "/books/new"
    end

    # Only supporting common file extensions of these image types.
    ext_whitelist = ['.gif', '.jpg', '.jpeg', '.png']
    extension = File.extname(file_hash[:filename])
    if !ext_whitelist.include? extension
      flash[:warning] = "Oops. It looks like your image wasn't a gif, jpeg, or png. Please choose a supported image type."
      redirect "/books/new"
    end

    # Write the contents of the upload to our uploads folder.
    # I may want to abstract this into a method as it grows 
    File.open('public/uploads/' + file_hash[:filename], "w") do |f|
      f.write(file_hash[:tempfile].read)
    end

    # Serialize the file hash as json so it can be saved in the database.
    params[:book]['cover_image'] = file_hash.to_json

  else
    # Assign a randomly selected cover image.

  end

  # Create book object and save it to the database.
  @book = Book.new(params[:book])

  if @book.save
    flash[:success] = "Your site has been created."
    redirect "/dashboard"
  else
    flash[:warning] = "Oops. Something went wrong. Try again."
    erb :"templates/new-book"
  end
end

# The Edit Book form sends a PUT request (updating data) here.
# If the book is updated successfully, redirect to the dashboard. Otherwise,
# render the edit form again with the failed @post object still in memory
# so they can retry.
put "/books/:id" do

  @book = Book.find(params[:id])

  if @book.update_attributes(params[:book])
    flash[:success] = "Your changes have been made (flash)"
    @books = unserialize_data(Book.all)
    redirect "/dashboard"
  else
    flash[:info] = "Oops. Something went wrong. Try again."
    erb :"templates/edit-book"
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
# @todo delete the uploaded image for a book when deleting the book.
delete "/books/:id" do
  # Only authenticated users can delete books.
  if !authenticated?; authenticate!; end

  # @todo: Ensure that a person can only delete "their books"
  # In other words... turn this into a multi-user system.

  @book_obj = Book.find(params[:id])
  book_data = unserialize_data(@book_obj)

  # Delete the uploaded book image.
  path_to_file = 'public/uploads/' + book_data.cover_image['filename']
  File.delete(path_to_file) if File.exist?(path_to_file)

  # Delete the database record for the book.
  @book_obj.destroy
  flash[:success] = "Bye Bye. Your book site has been deleted."
  redirect "/dashboard"
end

######################################
# Define Methods for use in our app
######################################

def unserialize_data(books)
  # [*books] allows us to iterate on both single and multiple items so we can unserialize single
  # book objects or multiple book objects. See http://www.rubyinside.com/21-ruby-tricks-902.html
  [*books].each do |book|
    # if !book.cover_image.nil?
      book.cover_image = JSON.parse(book.cover_image)
    # end
  end
  return books
end

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
  def delete_book(book_id)
    erb :"partials/_delete_book", locals: { book_id: book_id}
  end
 
  # I'll Need helpers for the following things in the edit form:
  #
  # - Given the github value, populates which option has been selected.
  #   (this is probably not needed since the select mechanism will likely change)
  # - Given the file URL, populate the file picker somehow.
  # - Given the license, populate the radio button somehow.
  # - Give the theme value, pre-highlight the appropriate image.

end