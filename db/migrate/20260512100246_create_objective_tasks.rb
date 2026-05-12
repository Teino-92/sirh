class CreateObjectiveTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :objective_tasks do |t|
      t.references :organization,  null: false, foreign_key: true
      t.references :objective,     null: false, foreign_key: true
      t.string     :title,         null: false, limit: 255
      t.text       :description
      t.date       :deadline
      t.references :assigned_to,   null: false, foreign_key: { to_table: :employees }
      t.string     :status,        null: false, default: 'todo'
      t.datetime   :completed_at
      t.references :completed_by,  null: true,  foreign_key: { to_table: :employees }
      t.datetime   :validated_at
      t.references :validated_by,  null: true,  foreign_key: { to_table: :employees }
      t.integer    :position,      null: false, default: 0
      t.timestamps
    end

    add_index :objective_tasks, [:organization_id, :objective_id]
    add_index :objective_tasks, :status
  end
end
