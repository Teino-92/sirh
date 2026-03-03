# frozen_string_literal: true

class AddBreakDurationToTimeEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :time_entries, :break_duration_minutes, :integer, default: 0, null: false
  end
end
