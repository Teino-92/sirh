class CreateObjectives < ActiveRecord::Migration[7.1]
  def change
    create_table :objectives do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :manager, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :employees }

      # Polymorphic owner (Employee or Team)
      t.references :owner, polymorphic: true, null: false, index: true

      t.string :title, null: false, limit: 255
      t.text :description
      t.string :status, null: false, default: 'draft', index: true
      t.string :priority, default: 'medium'
      t.date :deadline, null: false, index: true
      t.date :completed_at

      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    # Composite indexes for common queries
    add_index :objectives, [:organization_id, :status, :deadline], name: 'idx_objectives_org_status_deadline'
    add_index :objectives, [:manager_id, :status], name: 'idx_objectives_manager_status'
    add_index :objectives, [:owner_type, :owner_id, :status], name: 'idx_objectives_owner_status'

    # Partial index for overdue objectives (hot query)
    add_index :objectives, [:manager_id, :deadline],
              where: "status IN ('draft', 'in_progress', 'blocked')",
              name: 'idx_objectives_overdue'
  end
end
