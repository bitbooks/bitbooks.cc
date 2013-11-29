# app.rb
# The guts of our Sinatra app

require "sinatra"
require "sinatra/activerecord"
 
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

# Define behaviors at specific URLs
# Home page
get "/" do
  erb :"templates/index"
end

# User dashboard
get "/dashboard" do
  @books = Book.all
  erb :"templates/dashboard"
end


# Define Helpers
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
 
end