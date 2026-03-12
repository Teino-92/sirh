# frozen_string_literal: true

class SaasTrialExpiryJob < ApplicationJob
  queue_as :default

  def perform
    target_date = Date.current + 7.days

    Organization
      .where("trial_ends_at::date = ?", target_date)
      .find_each do |org|
        next if already_notified_today?(org)

        admin = find_admin_contact(org)
        next unless admin

        send_expiry_reminder(org, admin)
      rescue => e
        Rails.logger.error "[SaasTrialExpiryJob] Failed for org #{org.id}: #{e.class} — #{e.message}"
    end
  end

  private

  def already_notified_today?(org)
    last_sent = org.settings['trial_reminder_sent_on']
    last_sent.present? && last_sent == Date.current.iso8601
  end

  def find_admin_contact(org)
    org.employees
       .where(role: %w[manager hr admin])
       .order(Arel.sql("CASE role WHEN 'manager' THEN 1 WHEN 'hr' THEN 2 WHEN 'admin' THEN 3 END"))
       .first
  end

  def send_expiry_reminder(org, contact)
    conn = Faraday.new('https://api.resend.com') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    login_url = Rails.application.routes.url_helpers.new_employee_session_url(
      host:     ENV.fetch('APP_HOST', 'izi-rh.com'),
      protocol: 'https'
    )

    response = conn.post('/emails') do |req|
      req.headers['Authorization'] = "Bearer #{ENV['SMTP_PASSWORD']}"
      req.headers['Content-Type']  = 'application/json'
      req.body = {
        from:    "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>",
        to:      [contact.email],
        subject: "Votre essai Izi-RH se termine dans 7 jours — #{org.name}",
        html:    expiry_reminder_html(org, contact, login_url)
      }
    end

    if response.success?
      org.update_columns(
        settings: org.settings.merge('trial_reminder_sent_on' => Date.current.iso8601)
      )
      Rails.logger.info "[SaasTrialExpiryJob] Reminder sent to #{contact.email} for org #{org.id}"
    else
      Rails.logger.error "[SaasTrialExpiryJob] Resend error for org #{org.id}: #{response.status} #{response.body}"
      raise "Resend delivery failed (#{response.status})"
    end
  end

  def expiry_reminder_html(org, contact, login_url)
    <<~HTML
      <p>Bonjour #{contact.first_name},</p>

      <p>Votre essai gratuit Izi-RH pour <strong>#{org.name}</strong> se termine dans <strong>7 jours</strong>.</p>

      <p>Pour continuer à utiliser Izi-RH et ne pas perdre vos données, contactez-nous pour passer à un plan payant :</p>

      <p style="text-align:center;margin:24px 0;">
        <a href="mailto:bonjour@izi-rh.com?subject=Abonnement%20#{CGI.escape(org.name)}"
           style="background:#4F46E5;color:white;padding:12px 24px;border-radius:6px;text-decoration:none;display:inline-block;">
          Parler à l'équipe Izi-RH
        </a>
      </p>

      <p style="color:#6b7280;font-size:13px;">
        Votre essai se termine le <strong>#{org.trial_ends_at.strftime('%d/%m/%Y')}</strong>.
        Après cette date, votre accès sera suspendu mais vos données seront conservées 30 jours supplémentaires.
      </p>

      <p>— L'équipe Izi-RH</p>
    HTML
  end
end
