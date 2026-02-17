class CreateEvaluations < ActiveRecord::Migration[7.1]
  def change
    create_table :evaluations do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :employee, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :manager, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :employees }

      t.date :period_start, null: false
      t.date :period_end, null: false, index: true
      t.string :status, null: false, default: 'draft', index: true

      t.text :self_review
      t.text :manager_review
      t.integer :score
      t.date :completed_at

      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :evaluations, [:organization_id, :period_end], name: 'idx_evaluations_org_period'
    add_index :evaluations, [:manager_id, :status], name: 'idx_evaluations_manager_status'
    add_index :evaluations, [:employee_id, :period_end], name: 'idx_evaluations_employee_period'

    add_index :evaluations, [:employee_id, :period_start, :period_end],
              unique: true,
              name: 'idx_unique_evaluation_per_period'
  end
end
