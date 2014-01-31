class AddFieldsToBooks < ActiveRecord::Migration
  def up
    add_column(:books, :url, :string)
  end

  def down
    remove_column(:books, :url)
  end
end
