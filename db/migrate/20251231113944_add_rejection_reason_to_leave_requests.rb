class AddRejectionReasonToLeaveRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :leave_requests, :rejection_reason, :text
  end
end
