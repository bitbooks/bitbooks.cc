class AddOtherLicenseFields < ActiveRecord::Migration
  def up
    add_column(:books, :other_license, :string)
    add_column(:books, :other_license_url, :string)
  end

  def down
    remove_column(:books, :other_license)
    remove_column(:books, :other_license_url)
  end
end
