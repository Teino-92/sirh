# frozen_string_literal: true

# Refreshes the computed progress and integration score for an onboarding.
# Idempotent: safe to enqueue multiple times for the same onboarding.
# Enqueue from controllers after task completion — never from model callbacks.
class OnboardingScoreRefreshJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(onboarding_id)
    onboarding = Onboarding.find_by(id: onboarding_id)
    return unless onboarding&.active?

    # Services live at root level (app/services/) — not in the Onboarding namespace.
    # Onboarding is a class, not a module, and cannot serve as a Ruby namespace.
    # See config/application.rb for the Zeitwerk autoload path context.
    progress = OnboardingProgressCalculatorService.new(onboarding).call
    score    = OnboardingIntegrationScoreService.new(onboarding).call

    onboarding.update_columns(
      progress_percentage_cache: progress,
      integration_score_cache:   score
    )
  end
end
