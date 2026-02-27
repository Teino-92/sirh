# frozen_string_literal: true

class OnboardingTemplateTask < ApplicationRecord
  belongs_to :onboarding_template
  belongs_to :organization
  acts_as_tenant :organization

  TASK_TYPES    = %w[manual objective_30 objective_60 objective_90 training one_on_one].freeze
  ASSIGNED_ROLES = %w[hr manager employee].freeze

  validates :title,           presence: true, length: { maximum: 255 }
  validates :due_day_offset,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :task_type,       inclusion: { in: TASK_TYPES }
  validates :assigned_to_role, inclusion: { in: ASSIGNED_ROLES }

  scope :ordered, -> { order(:position) }
end
