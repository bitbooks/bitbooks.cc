class AddHookAndToken < ActiveRecord::Migration
  def up
    add_column(:books, :hook_id, :integer)
    add_column(:users, :token, :integer)
  end

  def down
    remove_column(:books, :hook_id)
    remove_column(:users, :token)
  end
end
