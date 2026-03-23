# frozen_string_literal: true

class AddIndexToLeaveBalancesOrganizationLeaveType < ActiveRecord::Migration[7.1]
  def change
    # Speeds up leave accrual jobs: find_or_create_by(organization:, employee:, leave_type:)
    add_index :leave_balances, [:organization_id, :leave_type],
              name: 'index_leave_balances_on_org_and_leave_type',
              if_not_exists: true
  end
end
