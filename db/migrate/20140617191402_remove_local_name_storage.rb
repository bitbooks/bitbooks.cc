class RemoveLocalNameStorage < ActiveRecord::Migration
  def up
    remove_column(:books, :gh_full_name)
    remove_column(:books, :github_pages_url)
    remove_column(:books, :github_url)
  end

  def down
    add_column(:books, :gh_full_name, :string)
    add_column(:books, :github_pages_url, :string)
    add_column(:books, :github_url, :string)
  end
end
