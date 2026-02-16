class CreateOneOnOnes < ActiveRecord::Migration[7.1]
  def change
    create_table :one_on_ones do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :manager, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :employee, null: false, foreign_key: { to_table: :employees }, index: true

      t.datetime :scheduled_at, null: false, index: true
      t.datetime :completed_at
      t.string :status, null: false, default: 'scheduled', index: true
      t.text :notes
      t.text :agenda

      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    # Composite indexes
    add_index :one_on_ones, [:manager_id, :status, :scheduled_at], name: 'idx_one_on_ones_manager'
    add_index :one_on_ones, [:employee_id, :scheduled_at], name: 'idx_one_on_ones_employee'

    # Partial index for upcoming 1:1s
    add_index :one_on_ones, [:manager_id, :scheduled_at],
              where: "status = 'scheduled'",
              name: 'idx_one_on_ones_upcoming'
  end
end
