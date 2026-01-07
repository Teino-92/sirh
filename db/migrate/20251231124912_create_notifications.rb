class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :title, null: false
      t.text :message
      t.string :notification_type, null: false
      t.datetime :read_at
      t.string :related_type
      t.integer :related_id

      t.timestamps
    end

    add_index :notifications, [:employee_id, :read_at]
    add_index :notifications, [:employee_id, :created_at]
  end
end
