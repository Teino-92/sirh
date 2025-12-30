class CreateLeaveRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :leave_requests do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :leave_type, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.decimal :days_count, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: 'pending'
      t.text :reason
      t.bigint :approved_by_id
      t.datetime :approved_at

      t.timestamps
    end

    add_index :leave_requests, :status
    add_index :leave_requests, :start_date
    add_index :leave_requests, :end_date
    add_index :leave_requests, [:employee_id, :status]
    add_index :leave_requests, :approved_by_id
    add_foreign_key :leave_requests, :employees, column: :approved_by_id
  end
end
