# frozen_string_literal: true

class OnboardingReview < ApplicationRecord
  belongs_to :onboarding
  belongs_to :organization
  acts_as_tenant :organization

  REVIEWER_TYPES = %w[employee manager].freeze
  REVIEW_DAYS    = [30, 90].freeze

  validates :reviewer_type,  inclusion: { in: REVIEWER_TYPES }
  validates :review_day,     inclusion: { in: REVIEW_DAYS }
  validates :onboarding_id,  uniqueness: {
    scope: %i[reviewer_type review_day],
    message: "a déjà un bilan pour ce type et ce jour"
  }

  def employee_confidence_score
    employee_feedback_json['confidence']&.to_i
  end

  def manager_integration_level
    manager_feedback_json['integration_level']&.to_i
  end
end
