# frozen_string_literal: true

# Immutable audit trail — one record per rule execution.
class RuleExecution < ApplicationRecord
  acts_as_tenant :organization

  RESULTS = %w[executed skipped failed].freeze

  belongs_to :organization
  belongs_to :business_rule

  validates :trigger,       presence: true
  validates :resource_type, presence: true
  validates :resource_id,   presence: true
  validates :result,        inclusion: { in: RESULTS }

  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
end
