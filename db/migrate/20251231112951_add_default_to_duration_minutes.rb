class AddDefaultToDurationMinutes < ActiveRecord::Migration[7.1]
  def up
    # Update existing NULL values to 0
    execute "UPDATE time_entries SET duration_minutes = 0 WHERE duration_minutes IS NULL"

    # Change column to have default value
    change_column_default :time_entries, :duration_minutes, from: nil, to: 0
    change_column_null :time_entries, :duration_minutes, false, 0
  end

  def down
    change_column_null :time_entries, :duration_minutes, true
    change_column_default :time_entries, :duration_minutes, from: 0, to: nil
  end
end
