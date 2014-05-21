class FixTokenDataType < ActiveRecord::Migration
  def up
    remove_column(:users, :token)
    add_column(:users, :token, :string)
  end

  def down
    remove_column(:users, :token)
    add_column(:users, :token, :integer)
  end
end
