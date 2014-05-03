# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140503170254) do

  create_table "books", force: true do |t|
    t.string "title"
    t.string "author"
    t.string "license"
    t.string "gh_full_name"
    t.string "theme"
    t.string "github_pages_url"
    t.string "license_name"
    t.string "license_url"
    t.string "username"
    t.string "domain"
    t.string "github_url"
  end

  create_table "users", force: true do |t|
    t.string "github_id"
    t.string "username"
    t.string "email"
  end

end
