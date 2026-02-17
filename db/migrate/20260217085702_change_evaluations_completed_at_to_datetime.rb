class ChangeEvaluationsCompletedAtToDatetime < ActiveRecord::Migration[7.1]
  def up
    change_column :evaluations, :completed_at, :datetime
  end

  def down
    change_column :evaluations, :completed_at, :date
  end
end
