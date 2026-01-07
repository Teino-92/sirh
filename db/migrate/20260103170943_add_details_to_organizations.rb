class AddDetailsToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :siret, :string
    add_column :organizations, :address, :text
  end
end
