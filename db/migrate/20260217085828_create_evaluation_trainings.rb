class CreateEvaluationTrainings < ActiveRecord::Migration[7.1]
  def change
    create_table :evaluation_trainings do |t|
      t.references :evaluation, null: false, foreign_key: true, index: true
      t.references :training_assignment, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :evaluation_trainings, [:evaluation_id, :training_assignment_id],
              unique: true, name: 'idx_unique_evaluation_trainings'
  end
end
