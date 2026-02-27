# frozen_string_literal: true

class OnboardingTemplate < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization

  has_many :onboarding_template_tasks, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
