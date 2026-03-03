class AddOrganizationIdToVersions < ActiveRecord::Migration[7.1]
  def change
    add_column :versions, :organization_id, :integer
  end
end
