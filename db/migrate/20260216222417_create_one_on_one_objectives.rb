class CreateOneOnOneObjectives < ActiveRecord::Migration[7.1]
  def change
    create_table :one_on_one_objectives do |t|
      t.references :one_on_one, null: false, foreign_key: true, index: true
      t.references :objective, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :one_on_one_objectives, [:one_on_one_id, :objective_id], unique: true, name: 'idx_unique_one_on_one_objectives'
  end
end
