class CreateActionItems < ActiveRecord::Migration[7.1]
  def change
    create_table :action_items do |t|
      t.references :one_on_one, null: false, foreign_key: true, index: true
      t.references :responsible, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :objective, null: true, foreign_key: true

      t.text :description, null: false
      t.date :deadline, null: false, index: true
      t.string :status, null: false, default: 'pending', index: true
      t.string :responsible_type, null: false
      t.date :completed_at
      t.text :completion_notes

      t.timestamps
    end

    # Composite indexes
    add_index :action_items, [:responsible_id, :status, :deadline], name: 'idx_action_items_responsible'

    # Partial index for overdue action items
    add_index :action_items, [:responsible_id, :deadline],
              where: "status IN ('pending', 'in_progress')",
              name: 'idx_action_items_overdue'
  end
end
