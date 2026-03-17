# frozen_string_literal: true

require 'cgi'

class OrgMergeMailerService
  def initialize(invitation:)
    @invitation = invitation
  end

  def send_invitation(acceptance_url)
    conn = resend_connection

    response = conn.post('/emails') do |req|
      req.headers['Authorization'] = "Bearer #{ENV['SMTP_PASSWORD']}"
      req.headers['Content-Type']  = 'application/json'
      req.body = {
        from:    "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>",
        to:      [@invitation.invited_email],
        subject: "Invitation à rejoindre #{@invitation.target_organization.name} sur Izi-RH",
        html:    invitation_html(acceptance_url)
      }
    end

    unless response.success?
      Rails.logger.error "[OrgMergeMailerService] Resend API error (send_invitation): #{response.status} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.warn "[OrgMergeMailerService] send_invitation failed: #{e.message}"
  end

  def send_completion_notification(admin_email)
    conn = resend_connection

    response = conn.post('/emails') do |req|
      req.headers['Authorization'] = "Bearer #{ENV['SMTP_PASSWORD']}"
      req.headers['Content-Type']  = 'application/json'
      req.body = {
        from:    "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>",
        to:      [admin_email],
        subject: "Fusion d'organisation terminée — #{@invitation.source_organization.name} → #{@invitation.target_organization.name}",
        html:    completion_html
      }
    end

    unless response.success?
      Rails.logger.error "[OrgMergeMailerService] Resend API error (send_completion_notification): #{response.status} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.warn "[OrgMergeMailerService] send_completion_notification failed: #{e.message}"
  end

  private

  def resend_connection
    Faraday.new('https://api.resend.com') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def invitation_html(acceptance_url)
    expiry_date  = @invitation.expires_at.strftime('%d/%m/%Y')
    source_name  = CGI.escapeHTML(@invitation.source_organization.name)
    target_name  = CGI.escapeHTML(@invitation.target_organization.name)
    safe_url     = CGI.escapeHTML(acceptance_url)

    <<~HTML
      <p>Bonjour,</p>
      <p>
        Vous avez reçu une invitation à fusionner votre espace <strong>#{source_name}</strong>
        avec l'organisation <strong>#{target_name}</strong> sur Izi-RH.
      </p>
      <p>
        Cette fusion migrera tous vos employés et données RH vers <strong>#{target_name}</strong>.
        Votre espace actuel sera dissous à l'issue du processus.
      </p>
      <p>
        <a href="#{safe_url}"
           style="background:#4F46E5;color:white;padding:12px 24px;border-radius:6px;text-decoration:none;display:inline-block;">
          Voir la proposition de fusion
        </a>
      </p>
      <p style="color:#6b7280;font-size:13px;">
        Cette invitation expire le <strong>#{expiry_date}</strong>.
        Si vous n'êtes pas à l'origine de cette demande, vous pouvez l'ignorer ou la décliner.
      </p>
      <p>— L'équipe Izi-RH</p>
    HTML
  end

  def completion_html
    source_name  = CGI.escapeHTML(@invitation.source_organization.name)
    target_name  = CGI.escapeHTML(@invitation.target_organization.name)
    completed_at = @invitation.completed_at&.strftime('%d/%m/%Y à %H:%M') || Time.current.strftime('%d/%m/%Y à %H:%M')
    stats        = @invitation.merge_log

    rows = stats.except('stripe_error', 'errors').map do |table, count|
      "<tr><td style='padding:4px 12px 4px 0;color:#6b7280'>#{CGI.escapeHTML(table.humanize)}</td><td><strong>#{count.to_i}</strong></td></tr>"
    end.join

    <<~HTML
      <h2>Fusion d'organisation terminée</h2>
      <p>
        L'organisation <strong>#{source_name}</strong> a été fusionnée avec succès dans
        <strong>#{target_name}</strong> le #{completed_at}.
      </p>
      <h3>Données migrées</h3>
      <table style="border-collapse:collapse;font-family:sans-serif;font-size:14px">
        #{rows}
      </table>
      <p style="color:#6b7280;font-size:13px;">
        L'espace #{source_name} est désormais dissous. Tous les utilisateurs ont accès à #{target_name}.
      </p>
      <p>— L'équipe Izi-RH</p>
    HTML
  end
end
