# frozen_string_literal: true

# Sends rule_engine notification emails in batch.
# Called by RulesEngine::NotificationDispatcher after in-app notifications are created.
#
# Accepts an array of employee IDs to batch-send emails without loading N ActiveRecord objects
# in the dispatcher. Each employee is loaded individually here to stay within job scope.
class RulesEngine::NotificationJob < ApplicationJob
  queue_as :default

  # @param employee_ids  [Array<Integer>]
  # @param subject       [String]
  # @param message       [String]
  # @param resource_type [String, nil]
  # @param resource_id   [Integer, nil]
  ALLOWED_RESOURCE_TYPES = %w[LeaveRequest OneOnOne Objective TrainingAssignment EmployeeOnboarding OnboardingTask].freeze

  def perform(employee_ids, subject, message, resource_type: nil, resource_id: nil)
    employees = Employee.where(id: employee_ids).to_a
    return if employees.empty?

    ActsAsTenant.with_tenant(employees.first.organization) do
      klass = ALLOWED_RESOURCE_TYPES.include?(resource_type) ? resource_type.constantize : nil
      resource = klass && resource_id ? klass.find_by(id: resource_id) : nil

      # deliver_later enqueues one independent job per recipient — idempotent on retry
      employees.each do |employee|
        RulesEngineMailer.rule_notification(
          employee: employee,
          subject:  subject,
          message:  message,
          resource: resource
        ).deliver_later
      end
    end
  end
end
