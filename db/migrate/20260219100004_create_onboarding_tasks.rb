class CreateOnboardingTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_tasks do |t|
      t.bigint   :onboarding_id,    null: false
      t.bigint   :organization_id,  null: false
      t.string   :title,            null: false
      t.text     :description
      t.string   :assigned_to_role, null: false
      t.bigint   :assigned_to_id
      t.date     :due_date,         null: false
      t.string   :status,           null: false, default: 'pending'
      t.string   :task_type,        null: false, default: 'manual'
      t.datetime :completed_at
      t.bigint   :completed_by_id
      t.jsonb    :metadata,         null: false, default: {}

      t.timestamps
    end

    add_index :onboarding_tasks, [:onboarding_id, :status],
              name: 'idx_onboarding_tasks_onboarding_status'
    add_index :onboarding_tasks, [:assigned_to_id, :due_date],
              name: 'idx_onboarding_tasks_assignee_due'
    add_index :onboarding_tasks, [:organization_id, :due_date],
              where: "status = 'pending'",
              name: 'idx_onboarding_tasks_org_pending_due'
    add_index :onboarding_tasks, :organization_id,
              name: 'index_onboarding_tasks_on_organization_id'

    add_foreign_key :onboarding_tasks, :onboardings
    add_foreign_key :onboarding_tasks, :organizations
    add_foreign_key :onboarding_tasks, :employees, column: :assigned_to_id
    add_foreign_key :onboarding_tasks, :employees, column: :completed_by_id
  end
end
