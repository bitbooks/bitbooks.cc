class DomainField < ActiveRecord::Migration
  def up
    add_column(:books, :domain, :string)
  end

  def down
    remove_column(:books, :domain)
  end
end
