class AddApprovalStepToLeaveRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :leave_requests, :current_approval_step, :integer
  end
end
