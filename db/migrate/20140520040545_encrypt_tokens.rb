class EncryptTokens < ActiveRecord::Migration
  def up
    remove_column(:users, :token)
    add_column(:users, :encrypted_token, :string)
  end

  def down
    remove_column(:users, :encrypted_token)
    add_column(:users, :token, :string)
  end
end
