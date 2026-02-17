class EvaluationObjective < ApplicationRecord
  belongs_to :evaluation
  belongs_to :objective

  validates :evaluation_id, uniqueness: { scope: :objective_id }
end
