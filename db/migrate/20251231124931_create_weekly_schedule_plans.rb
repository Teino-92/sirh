class CreateWeeklySchedulePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :weekly_schedule_plans do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :week_start_date, null: false
      t.jsonb :schedule_pattern, null: false, default: '{}'
      t.text :notes

      t.timestamps
    end

    add_index :weekly_schedule_plans, [:employee_id, :week_start_date], unique: true
  end
end
