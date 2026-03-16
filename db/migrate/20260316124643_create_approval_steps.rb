class CreateApprovalSteps < ActiveRecord::Migration[7.1]
  def change
    create_table :approval_steps do |t|
      t.references :organization,   null: false, foreign_key: true
      t.string  :resource_type,     null: false  # "LeaveRequest"
      t.integer :resource_id,       null: false
      t.integer :step_order,        null: false  # 1, 2, 3...
      t.string  :required_role,     null: false  # "manager", "hr", "admin", "n2"
      t.references :approved_by,    foreign_key: { to_table: :employees }
      t.datetime :approved_at
      t.datetime :rejected_at
      t.references :rejected_by,    foreign_key: { to_table: :employees }
      t.string  :status,            null: false, default: 'pending'  # pending | approved | rejected | skipped
      t.text    :comment

      t.timestamps
    end

    add_index :approval_steps, [ :resource_type, :resource_id, :step_order ],
              name: 'idx_approval_steps_resource_order', unique: true
    add_index :approval_steps, [ :organization_id, :status ]
  end
end
