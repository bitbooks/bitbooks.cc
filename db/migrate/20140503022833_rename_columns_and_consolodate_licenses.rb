class RenameColumnsAndConsolodateLicenses < ActiveRecord::Migration
  def up
    rename_column(:books, :other_license, :license_name)
    rename_column(:books, :other_license_url, :license_url)
    rename_column(:books, :url, :github_pages_url)
    add_column(:books, :github_url, :string)
  end

  def down
    rename_column(:books, :license_name, :other_license)
    rename_column(:books, :license_url, :other_license_url)
    rename_column(:books, :github_pages_url, :url)
    remove_column(:books, :github_url)
  end
end
