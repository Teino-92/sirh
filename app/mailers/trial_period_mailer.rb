# frozen_string_literal: true

class TrialPeriodMailer < ApplicationMailer
  # Envoyé au manager J-7 avant la fin de période d'essai
  def reminder(employee, recipient)
    @employee      = employee
    @recipient     = recipient
    @dashboard_url = authenticated_root_url

    mail(
      to:      recipient.email,
      subject: "Période d'essai — Action requise : #{employee.full_name}"
    )
  end

  # Envoyé aux RH après décision du manager
  def decision_to_hr(employee, manager, decision)
    @employee  = employee
    @manager   = manager
    @decision  = decision

    hrs = employee.organization.employees.where(role: %w[hr admin])
    return if hrs.empty?

    mail(
      to:      hrs.pluck(:email),
      subject: "Décision période d'essai — #{employee.full_name}"
    )
  end
end
