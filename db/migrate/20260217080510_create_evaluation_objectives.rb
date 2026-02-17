class CreateEvaluationObjectives < ActiveRecord::Migration[7.1]
  def change
    create_table :evaluation_objectives do |t|
      t.references :evaluation, null: false, foreign_key: true, index: true
      t.references :objective, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :evaluation_objectives, [:evaluation_id, :objective_id],
              unique: true,
              name: 'idx_unique_evaluation_objectives'
  end
end
