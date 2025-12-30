class CreateTimeEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :time_entries do |t|
      t.references :employee, null: false, foreign_key: true
      t.datetime :clock_in, null: false
      t.datetime :clock_out
      t.integer :duration_minutes
      t.jsonb :location, default: {}
      t.boolean :manual_override, default: false, null: false
      t.text :notes

      t.timestamps
    end

    add_index :time_entries, :clock_in
    add_index :time_entries, :clock_out
    add_index :time_entries, [:employee_id, :clock_in]
    add_index :time_entries, [:employee_id, :clock_out]
  end
end
