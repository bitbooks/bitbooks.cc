class UserBookRelationships < ActiveRecord::Migration
  def up
    add_column(:books, :user_id, :integer)
    add_column(:books, :github_id, :integer)
    remove_column(:users, :github_id, :string)
    add_column(:users, :github_id, :integer)
  end

  def down
    remove_column(:books, :user_id)
    remove_column(:books, :github_id)
    remove_column(:users, :github_id)
    add_column(:users, :github_id, :string)
  end
end
