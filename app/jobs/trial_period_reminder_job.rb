# frozen_string_literal: true

class TrialPeriodReminderJob < ApplicationJob
  queue_as :default

  def perform
    target_date = Date.today + 7.days

    Employee.where(trial_period_end: target_date)
            .includes(:manager, :organization)
            .find_each do |employee|
      ActsAsTenant.with_tenant(employee.organization) do
        next if already_notified?(employee)

        recipients = resolve_recipients(employee)
        next if recipients.empty?

        recipients.each do |recipient|
          create_notification(employee, recipient)
          TrialPeriodMailer.reminder(employee, recipient).deliver_later
        end
      end
    end
  end

  private

  def already_notified?(employee)
    Notification.where(
      organization:      employee.organization,
      notification_type: 'trial_period_ending',
      related_type:      'Employee',
      related_id:        employee.id
    ).where('created_at > ?', 24.hours.ago).exists?
  end

  def resolve_recipients(employee)
    if employee.manager.present?
      [employee.manager]
    else
      employee.organization.employees.where(role: %w[hr admin]).to_a
    end
  end

  def create_notification(employee, recipient)
    Notification.create!(
      organization:      employee.organization,
      employee:          recipient,
      title:             "Période d'essai — #{employee.full_name}",
      message:           "La période d'essai de #{employee.full_name} se termine le #{I18n.l(employee.trial_period_end, format: :long)}. Veuillez prendre une décision.",
      notification_type: 'trial_period_ending',
      related_type:      'Employee',
      related_id:        employee.id
    )
  end
end
