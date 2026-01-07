class AddHalfDayFieldsToLeaveRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :leave_requests, :start_half_day, :string
    add_column :leave_requests, :end_half_day, :string
  end
end
