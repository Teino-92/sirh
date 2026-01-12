# frozen_string_literal: true

class TimeEntryMailer < ApplicationMailer
  default from: 'noreply@easy-rh.com'

  # Rappel hebdomadaire pour valider les pointages de l'équipe
  def weekly_validation_reminder(manager)
    @manager = manager
    @pending_count = TimeEntry
                     .joins(:employee)
                     .where(employees: { manager_id: manager.id })
                     .pending_validation
                     .count

    # Get last week's date range
    @last_week_start = (Date.current - 1.week).beginning_of_week
    @last_week_end = (Date.current - 1.week).end_of_week

    mail(
      to: @manager.email,
      subject: "Rappel : #{@pending_count} pointage#{'s' if @pending_count > 1} en attente de validation"
    )
  end
end
