class AddNotNullConstraints < ActiveRecord::Migration[7.1]
  def change
    # Après le backfill, rendre organization_id NOT NULL
    tables = [
      :time_entries,
      :leave_requests,
      :leave_balances,
      :work_schedules,
      :weekly_schedule_plans,
      :notifications
    ]

    tables.each do |table|
      change_column_null table, :organization_id, false
    end
  end
end
