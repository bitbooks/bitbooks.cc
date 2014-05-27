bitbooks.cc
===========

This is a Sinatra application, running bitbooks.cc. Its components include:

* A Sinatra application --- Serves the main website
* A Sidekiq process --- Provides background jobs for processing
* A Postgresql database --- Stores records of users and books (it is Sqlite in development)

Sidekiq uses HTTP requests to send jobs to Bitbinder, a second application that
pulls content from github, builds it into a book, and pushes the result to
github pages.