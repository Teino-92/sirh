# frozen_string_literal: true

class AddEscalationFieldsToApprovalSteps < ActiveRecord::Migration[7.1]
  def change
    add_column :approval_steps, :escalate_after_hours, :integer
    add_column :approval_steps, :escalate_to_role,     :string
    add_column :approval_steps, :escalate_at,          :datetime
    add_column :approval_steps, :escalated,            :boolean, null: false, default: false

    add_index :approval_steps, :escalate_at
  end
end
