# frozen_string_literal: true

# A configurable business rule for an organisation.
#
# Structure:
#   trigger    — event that fires this rule (e.g. "leave_request.submitted")
#   conditions — array of { field, operator, value } hashes (AND logic)
#   actions    — array of { type, ... } hashes executed in order when all conditions match
#   priority   — lower number = evaluated first
#
# Example:
#   {
#     trigger: "leave_request.submitted",
#     conditions: [
#       { "field" => "days_count",  "operator" => "gte", "value" => 5 },
#       { "field" => "leave_type",  "operator" => "eq",  "value" => "CP" }
#     ],
#     actions: [
#       { "type" => "require_approval", "role" => "manager", "order" => 1 },
#       { "type" => "require_approval", "role" => "hr",      "order" => 2 }
#     ]
#   }
class BusinessRule < ApplicationRecord
  acts_as_tenant :organization

  # Documentation only — not used for validation.
  # Kept in sync with BusinessRulesHelper::TRIGGER_LABELS.
  KNOWN_TRIGGERS = %w[
    leave_request.submitted leave_request.approved leave_request.rejected leave_request.cancelled
    one_on_one.scheduled one_on_one.completed one_on_one.cancelled
    objective.assigned objective.completed
    training_assignment.assigned training_assignment.completed
    onboarding.started onboarding.task_completed
    evaluation.completed
  ].freeze

  # Documentation only — not used for validation.
  KNOWN_ACTION_TYPES = %w[require_approval auto_approve block notify escalate_after].freeze

  belongs_to :organization
  has_many   :rule_executions, dependent: :destroy

  validates :name,     presence: true
  validates :trigger,  presence: true, format: { with: /\A\w+(\.\w+)+\z/, message: "doit être au format 'domain.event'" }
  validates :actions,  presence: true
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate  :multi_action_rules_have_order

  private

  # When a rule has multiple actions, each must have an explicit 'order' key to ensure
  # deterministic execution. A single-action rule may omit 'order' (defaults to 0).
  def multi_action_rules_have_order
    return unless actions.is_a?(Array) && actions.size > 1
    actions.each_with_index do |action, i|
      unless action.is_a?(Hash) && action['order'].present?
        errors.add(:actions, "l'action ##{i + 1} doit avoir une clé 'order' quand plusieurs actions sont définies")
      end
    end
  end

  scope :active,      -> { where(active: true) }
  scope :for_trigger, ->(trigger) { active.where(trigger: trigger).order(:priority) }
end
