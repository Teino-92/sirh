# frozen_string_literal: true

# Generic mailer for rules engine notifications.
# Sends a rule-triggered notification email to a specific employee.
class RulesEngineMailer < ApplicationMailer
  # @param employee    [Employee]
  # @param subject     [String]
  # @param message     [String]
  # @param resource    [ApplicationRecord] the resource that triggered the rule (optional)
  def rule_notification(employee:, subject:, message:, resource: nil)
    @employee = employee
    @message  = message
    @resource = resource

    mail(to: employee.email, subject: subject)
  end
end
