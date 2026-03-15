# frozen_string_literal: true

class TrialRegistrationService
  Result = Struct.new(:success?, :employee, :errors)

  ALLOWED_PLANS = %w[manager_os sirh].freeze

  BILLING_MODEL_FOR_PLAN = {
    'manager_os' => 'per_team',
    'sirh'       => 'per_employee'
  }.freeze

  def initialize(params)
    @org_name   = params[:organization_name].to_s.strip
    @first_name = params[:first_name].to_s.strip
    @last_name  = params[:last_name].to_s.strip
    @email      = params[:email].to_s.strip.downcase
    @plan       = ALLOWED_PLANS.include?(params[:plan].to_s) ? params[:plan].to_s : "sirh"
  end

  def call
    employee = nil

    ActiveRecord::Base.transaction do
      org = Organization.create!(
        name:          @org_name,
        plan:          @plan,
        billing_model: BILLING_MODEL_FOR_PLAN[@plan],
        settings:      Organization.new.default_settings,
        trial_ends_at: 30.days.from_now
      )

      employee = ActsAsTenant.with_tenant(org) do
        Employee.create!(
          organization:  org,
          first_name:    @first_name,
          last_name:     @last_name,
          email:         @email,
          password:      SecureRandom.hex(16),
          role:          @plan == 'sirh' ? 'hr' : 'admin',
          contract_type: 'CDI',
          start_date:    Date.current
        )
      end
    end

    # Generate reset token and send via Resend HTTP API (SMTP is blocked on Render free)
    raw_token, hashed_token = Devise.token_generator.generate(Employee, :reset_password_token)
    employee.update_columns(
      reset_password_token:   hashed_token,
      reset_password_sent_at: Time.current
    )

    reset_url = Rails.application.routes.url_helpers.edit_employee_password_url(
      reset_password_token: raw_token,
      host: ENV.fetch('APP_HOST', 'izi-rh.com'),
      protocol: 'https'
    )

    send_welcome_email(employee, reset_url)
    send_admin_notification(employee)

    Result.new(true, employee, [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, nil, e.record.errors.full_messages)
  rescue StandardError => e
    Rails.logger.error "[TrialRegistration] Failed: #{e.class} — #{e.message}"
    Result.new(false, nil, ["Une erreur est survenue lors de la création de votre espace. Veuillez réessayer."])
  end

  private

  def send_admin_notification(employee)
    admin_email = ENV.fetch('ADMIN_NOTIFICATION_EMAIL', 'matteo@izi-rh.com')
    plan_label  = employee.organization.plan.humanize

    conn = Faraday.new('https://api.resend.com') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    conn.post('/emails') do |req|
      req.headers['Authorization'] = "Bearer #{ENV['SMTP_PASSWORD']}"
      req.headers['Content-Type']  = 'application/json'
      req.body = {
        from:    "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>",
        to:      [admin_email],
        subject: "🆕 Nouveau trial — #{employee.organization.name} (#{plan_label})",
        html:    <<~HTML
          <h2>Nouvelle inscription trial</h2>
          <table style="border-collapse:collapse;font-family:sans-serif;font-size:14px">
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Organisation</td><td><strong>#{employee.organization.name}</strong></td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Plan</td><td><strong>#{plan_label}</strong></td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Contact</td><td>#{employee.full_name} — #{employee.email}</td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Fin du trial</td><td>#{employee.organization.trial_ends_at.strftime('%d/%m/%Y')}</td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Date</td><td>#{Time.current.strftime('%d/%m/%Y %H:%M')}</td></tr>
          </table>
        HTML
      }
    end
  rescue StandardError => e
    Rails.logger.warn "[TrialRegistration] Admin notification failed: #{e.message}"
    # Non-blocking — ne pas faire échouer l'inscription si la notif plante
  end

  def send_welcome_email(employee, reset_url)
    conn = Faraday.new('https://api.resend.com') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    response = conn.post('/emails') do |req|
      req.headers['Authorization'] = "Bearer #{ENV['SMTP_PASSWORD']}"
      req.headers['Content-Type']  = 'application/json'
      req.body = {
        from:    "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>",
        to:      [employee.email],
        subject: "Bienvenue sur Izi-RH — Définissez votre mot de passe",
        html:    <<~HTML
          <p>Bonjour #{employee.first_name},</p>
          <p>Votre espace Izi-RH est prêt. Cliquez sur le lien ci-dessous pour définir votre mot de passe :</p>
          <p><a href="#{reset_url}" style="background:#4F46E5;color:white;padding:12px 24px;border-radius:6px;text-decoration:none;display:inline-block;">Définir mon mot de passe</a></p>
          <p>Ce lien est valable 6 heures.</p>
          <p>— L'équipe Izi-RH</p>
        HTML
      }
    end

    unless response.success?
      Rails.logger.error "[TrialRegistration] Resend API error: #{response.status} #{response.body}"
      raise "Resend delivery failed (#{response.status}): #{response.body}"
    end
  end
end
