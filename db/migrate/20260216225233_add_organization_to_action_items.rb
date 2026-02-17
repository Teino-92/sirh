class AddOrganizationToActionItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :action_items, :organization, null: true, foreign_key: true, index: true

    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE action_items
          SET organization_id = one_on_ones.organization_id
          FROM one_on_ones
          WHERE action_items.one_on_one_id = one_on_ones.id
        SQL

        change_column_null :action_items, :organization_id, false
      end
    end
  end
end
