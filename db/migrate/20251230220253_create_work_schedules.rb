class CreateWorkSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :work_schedules do |t|
      t.references :employee, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.decimal :weekly_hours, precision: 10, scale: 2, null: false, default: 35
      t.jsonb :schedule_pattern, default: {}, null: false
      t.decimal :rtt_accrual_rate, precision: 10, scale: 2, default: 0

      t.timestamps
    end
  end
end
