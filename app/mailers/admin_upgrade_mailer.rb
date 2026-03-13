# frozen_string_literal: true

class AdminUpgradeMailer < ApplicationMailer
  def upgrade_requested(organization, contact_name: nil, contact_email: nil, contact_message: nil)
    @org             = organization
    @contact_name    = contact_name
    @contact_email   = contact_email
    @contact_message = contact_message
    mail(
      to:       ENV.fetch("ADMIN_EMAIL", "contact@izi-rh.com"),
      reply_to: contact_email.presence,
      subject:  "[Izi-RH] Demande d'upgrade SIRH — #{organization.name}"
    )
  end
end
