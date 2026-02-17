class EvaluationTraining < ApplicationRecord
  belongs_to :evaluation
  belongs_to :training_assignment

  validates :evaluation_id, uniqueness: { scope: :training_assignment_id }
end
