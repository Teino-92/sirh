class AddRejectionToTimeEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :time_entries, :rejected_at, :datetime
    add_reference :time_entries, :rejected_by, foreign_key: { to_table: :employees }
    add_column :time_entries, :rejection_reason, :text
    add_index :time_entries, :rejected_at
  end
end
