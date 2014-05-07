class RemoveUsername < ActiveRecord::Migration
  def up
    remove_column(:books, :username, :string)
  end

  def down
    add_column(:books, :username, :string)
  end
end
