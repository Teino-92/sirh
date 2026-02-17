class EvaluationObjective < ApplicationRecord
  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  belongs_to :evaluation
  belongs_to :objective

  validates :evaluation_id, uniqueness: { scope: :objective_id }
end
