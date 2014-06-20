class RestoreGhFullName < ActiveRecord::Migration
  def up
    add_column(:books, :gh_full_name, :string)
  end

  def down
    remove_column(:books, :gh_full_name)
  end
end
