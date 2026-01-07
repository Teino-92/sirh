class AddValidationToTimeEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :time_entries, :validated_at, :datetime
    add_reference :time_entries, :validated_by, foreign_key: { to_table: :employees }
    add_index :time_entries, :validated_at
  end
end
