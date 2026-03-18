# frozen_string_literal: true

class AdminUpgradeMailer < ApplicationMailer
  def upgrade_requested(organization, contact_name: nil, contact_email: nil, contact_message: nil)
    @org             = organization
    @contact_name    = contact_name
    @contact_email   = contact_email
    @contact_message = contact_message

    token = Rails.application.message_verifier("sirh_upgrade")
                 .generate({ org_id: organization.id }, expires_in: 7.days)
    @magic_link = Rails.application.routes.url_helpers.super_admin_upgrade_preview_url(
      token,
      host:     ENV.fetch("APP_HOST", "izi-rh.com"),
      protocol: "https"
    )

    mail(
      to:       ENV.fetch("ADMIN_EMAIL", "contact@izi-rh.com"),
      reply_to: contact_email.presence,
      subject:  "[Izi-RH] Demande d'upgrade SIRH — #{organization.name}"
    )
  end
end
