# frozen_string_literal: true

class WeeklyTimeValidationReminderJob < ApplicationJob
  queue_as :default

  # Envoie un rappel hebdomadaire à tous les managers pour valider les pointages
  def perform
    # Find all managers with pending time entries from their team
    managers = Employee.where(role: %w[manager hr admin]).find_each do |manager|
      # Check if manager has team members
      next if manager.team_members.empty?

      # Check if there are pending time entries for this manager's team
      pending_count = TimeEntry
                      .joins(:employee)
                      .where(employees: { manager_id: manager.id })
                      .pending_validation
                      .count

      # Only send email if there are pending entries
      next if pending_count.zero?

      # TODO: Implement TimeEntryMailer in Sprint 2.x
      Rails.logger.info "[EMAIL] Validation reminder: #{manager.email} has #{pending_count} pending time entries"
    end
  end
end
