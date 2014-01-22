class AddFieldsToBooks < ActiveRecord::Migration
  def up
    add_column(:books, :cover_image, :string)
    add_column(:books, :subdomain, :string)
  end

  def down
    remove_column(:books, :cover_image)
    remove_column(:books, :subdomain)
  end
end
