class VariousUpdates < ActiveRecord::Migration
  def up
    remove_column(:books, :gh_full_name)
    remove_column(:users, :username)
    add_column(:users, :plan, :string)
    add_column(:books, :status, :string)
    rename_column(:books, :github_id, :repo_id)
  end

  def down
    add_column(:books, :gh_full_name, :string)
    add_column(:users, :username, :string)
    remove_column(:users, :plan)
    remove_column(:books, :status)
    rename_column(:books, :repo_id, :github_id)
  end
end
