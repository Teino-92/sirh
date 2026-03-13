# frozen_string_literal: true

class AdminUpgradeMailer < ApplicationMailer
  def upgrade_requested(organization)
    @org = organization
    mail(
      to:      ENV.fetch("ADMIN_EMAIL", "contact@izi-rh.com"),
      subject: "[Izi-RH] Demande d'upgrade SIRH — #{organization.name}"
    )
  end
end
