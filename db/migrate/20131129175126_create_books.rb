class CreateBooks < ActiveRecord::Migration
  def up
    create_table :books do |t|
      t.string :title
      t.string :author
      t.string :license
      t.string :github_url
      t.string :theme
    end
    Book.create(title: "Example Book", author: "Bryan Braun", license: "Attribution", github_url: "https://github.com/bryanbraun/example-book", theme: "Glide")
  end

  def down
    drop_table :books
  end
end
