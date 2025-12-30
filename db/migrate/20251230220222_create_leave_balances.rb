class CreateLeaveBalances < ActiveRecord::Migration[7.1]
  def change
    create_table :leave_balances do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :leave_type, null: false
      t.decimal :balance, precision: 10, scale: 2, default: 0, null: false
      t.decimal :accrued_this_year, precision: 10, scale: 2, default: 0, null: false
      t.decimal :used_this_year, precision: 10, scale: 2, default: 0, null: false
      t.date :expires_at

      t.timestamps
    end

    add_index :leave_balances, [:employee_id, :leave_type], unique: true
    add_index :leave_balances, :leave_type
    add_index :leave_balances, :expires_at
  end
end
