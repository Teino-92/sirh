# frozen_string_literal: true

class AddMergeColumnsToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :status, :string, default: 'active', null: false
    add_column :organizations, :merged_into_id, :bigint
    add_column :organizations, :merged_at, :datetime
    add_index :organizations, :status
    add_index :organizations, :merged_into_id, where: "merged_into_id IS NOT NULL"
  end
end
