class CreateOnboardings < ActiveRecord::Migration[7.1]
  def change
    create_table :onboardings do |t|
      t.bigint :organization_id,          null: false
      t.bigint :employee_id,              null: false
      t.bigint :manager_id,               null: false
      t.bigint :onboarding_template_id,   null: false
      t.date   :start_date,               null: false
      t.date   :end_date,                 null: false
      t.string :status,                   null: false, default: 'active'
      t.text   :notes

      t.timestamps
    end

    # One active onboarding per employee
    add_index :onboardings, :employee_id,
              unique: true,
              where: "status = 'active'",
              name: 'idx_onboardings_employee_active'
    add_index :onboardings, [:manager_id, :status],
              name: 'idx_onboardings_manager_status'
    add_index :onboardings, [:organization_id, :status],
              name: 'idx_onboardings_org_status'
    add_index :onboardings, :organization_id,
              name: 'index_onboardings_on_organization_id'

    add_foreign_key :onboardings, :organizations
    add_foreign_key :onboardings, :employees
    add_foreign_key :onboardings, :employees, column: :manager_id
    add_foreign_key :onboardings, :onboarding_templates
  end
end
