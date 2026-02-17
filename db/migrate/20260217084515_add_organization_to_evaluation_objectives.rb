class AddOrganizationToEvaluationObjectives < ActiveRecord::Migration[7.1]
  def up
    add_reference :evaluation_objectives, :organization, null: true, foreign_key: true, index: true

    execute <<-SQL
      UPDATE evaluation_objectives
      SET organization_id = evaluations.organization_id
      FROM evaluations
      WHERE evaluation_objectives.evaluation_id = evaluations.id
    SQL

    change_column_null :evaluation_objectives, :organization_id, false
  end

  def down
    remove_reference :evaluation_objectives, :organization, foreign_key: true, index: true
  end
end
