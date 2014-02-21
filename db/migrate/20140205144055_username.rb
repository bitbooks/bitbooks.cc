class Username < ActiveRecord::Migration
  def up
    add_column(:books, :username, :string)
    rename_column(:books, :github_url, :gh_full_name)
  end

  def down
    remove_column(:books, :username)
    rename_column(:books, :gh_full_name, :github_url)
  end
end
