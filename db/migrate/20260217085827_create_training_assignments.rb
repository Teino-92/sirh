class CreateTrainingAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :training_assignments do |t|
      t.references :training, null: false, foreign_key: true, index: true
      t.references :employee, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :assigned_by, null: false, foreign_key: { to_table: :employees }
      t.references :objective, null: true, foreign_key: true  # Optional link

      t.string :status, null: false, default: 'assigned', index: true
      t.date :assigned_at, null: false, default: -> { 'CURRENT_DATE' }
      t.date :deadline, index: true
      t.datetime :completed_at
      t.text :completion_notes

      t.timestamps
    end

    # Composite indexes
    add_index :training_assignments, [:employee_id, :status], name: 'idx_training_assignments_employee'
    add_index :training_assignments, [:assigned_by_id, :status], name: 'idx_training_assignments_manager'

    # Partial index for active assignments with deadline (supports overdue queries)
    # Note: CURRENT_DATE not allowed in PG partial index predicates (not IMMUTABLE)
    add_index :training_assignments, [:employee_id, :deadline],
              where: "status IN ('assigned', 'in_progress') AND deadline IS NOT NULL",
              name: 'idx_training_assignments_overdue'

    # Uniqueness: 1 active assignment per employee per training
    add_index :training_assignments, [:employee_id, :training_id],
              unique: true,
              where: "status IN ('assigned', 'in_progress')",
              name: 'idx_unique_active_assignment'
  end
end
