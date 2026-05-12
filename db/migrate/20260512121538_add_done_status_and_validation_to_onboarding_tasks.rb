class AddDoneStatusAndValidationToOnboardingTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :onboarding_tasks, :validated_at, :datetime
    add_column :onboarding_tasks, :validated_by_id, :bigint
    add_foreign_key :onboarding_tasks, :employees, column: :validated_by_id

    remove_index :onboarding_tasks, name: "idx_onboarding_tasks_org_pending_due"
    add_index :onboarding_tasks, [:organization_id, :due_date],
              name: "idx_onboarding_tasks_org_active_due",
              where: "(status IN ('pending', 'done'))"
  end
end
