class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # LeaveRequest - status + date filtering
    add_index :leave_requests, [:employee_id, :status],
              name: 'idx_leave_requests_employee_status'

    add_index :leave_requests, [:start_date, :end_date],
              name: 'idx_leave_requests_date_range'

    # Partial index for pending requests (most common query)
    add_index :leave_requests, [:status, :created_at],
              name: 'idx_leave_requests_status_created',
              where: "status = 'pending'"

    # TimeEntry - employee + date range
    add_index :time_entries, [:employee_id, :clock_in],
              name: 'idx_time_entries_employee_clock_in'

    # Partial index for pending validation
    add_index :time_entries, [:employee_id, :validated_at],
              name: 'idx_time_entries_employee_validated',
              where: 'validated_at IS NULL'

    # Employee - manager hierarchy queries
    add_index :employees, [:manager_id, :organization_id],
              name: 'idx_employees_manager_org'

    # Note: notifications table already has indexes on employee_id + read_at and employee_id + created_at
  end
end
