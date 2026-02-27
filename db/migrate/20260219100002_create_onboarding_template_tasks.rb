class CreateOnboardingTemplateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_template_tasks do |t|
      t.bigint  :onboarding_template_id, null: false
      t.bigint  :organization_id,        null: false
      t.string  :title,                  null: false
      t.text    :description
      t.string  :assigned_to_role,       null: false
      t.integer :due_day_offset,         null: false
      t.string  :task_type,              null: false, default: 'manual'
      t.integer :position,               null: false, default: 0
      t.jsonb   :metadata,               null: false, default: {}

      t.timestamps
    end

    add_index :onboarding_template_tasks, [:onboarding_template_id, :position],
              name: 'idx_template_tasks_template_position'
    add_index :onboarding_template_tasks, :organization_id,
              name: 'index_onboarding_template_tasks_on_organization_id'

    add_foreign_key :onboarding_template_tasks, :onboarding_templates
    add_foreign_key :onboarding_template_tasks, :organizations
  end
end
