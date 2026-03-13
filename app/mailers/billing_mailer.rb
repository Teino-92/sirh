# frozen_string_literal: true

class BillingMailer < ApplicationMailer
  def payment_failed(organization, employee)
    @org      = organization
    @employee = employee
    mail(
      to:      employee.email,
      subject: "[Izi-RH] Échec de paiement — action requise"
    )
  end
end
