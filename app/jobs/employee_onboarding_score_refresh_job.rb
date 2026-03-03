# frozen_string_literal: true

# Refreshes the computed progress and integration score for an employee onboarding.
# Idempotent: safe to enqueue multiple times for the same onboarding.
# Enqueue from controllers after task completion — never from model callbacks.
class EmployeeOnboardingScoreRefreshJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(employee_onboarding_id)
    onboarding = EmployeeOnboarding.find_by(id: employee_onboarding_id)
    return unless onboarding&.active?

    progress = EmployeeOnboardingProgressCalculatorService.new(onboarding).call
    score    = EmployeeOnboardingIntegrationScoreService.new(onboarding).call

    onboarding.update_columns(
      progress_percentage_cache: progress,
      integration_score_cache:   score
    )
  end
end
