# frozen_string_literal: true

class SubscriptionUpdatedHandler
  STRIPE_STATUS_MAP = {
    "active"             => "active",
    "trialing"           => "trialing",
    "past_due"           => "past_due",
    "canceled"           => "canceled",
    "incomplete"         => "incomplete",
    "incomplete_expired" => "canceled"
  }.freeze

  # Lookup key → plan interne
  PRICE_PLAN_MAP = {
    "managerOS_monthly"      => "manager_os",
    "sirh_essentiel_monthly" => "sirh_essential",
    "sirh_pro_monthly"       => "sirh_pro"
  }.freeze

  def call(event)
    stripe_sub = event.data.object
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)

    unless sub
      Rails.logger.warn "[Webhook:SubscriptionUpdated] No subscription found for #{stripe_sub.id}"
      return
    end

    new_status = STRIPE_STATUS_MAP.fetch(stripe_sub.status, "active")
    new_plan   = resolve_plan(stripe_sub)

    attrs = {
      status:               new_status,
      current_period_end:   Time.at(stripe_sub.current_period_end),
      cancel_at_period_end: stripe_sub.cancel_at_period_end,
      last_webhook_at:      Time.current
    }
    attrs[:plan] = new_plan if new_plan.present? && new_plan != sub.plan

    was_active = sub.status == 'active'
    sub.update!(attrs)

    Rails.logger.info "[Webhook:SubscriptionUpdated] Sub #{stripe_sub.id} → status=#{new_status} plan=#{new_plan || sub.plan}"

    send_admin_notification(sub, new_plan || sub.plan) if new_status == 'active' && !was_active
  end

  private

  def send_admin_notification(sub, plan)
    admin_email = ENV.fetch('ADMIN_NOTIFICATION_EMAIL', 'matteo@izi-rh.com')
    org         = sub.organization

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
        subject: "💳 Nouvelle souscription — #{org.name} (#{plan.humanize})",
        html:    <<~HTML
          <h2>Nouvelle souscription payante</h2>
          <table style="border-collapse:collapse;font-family:sans-serif;font-size:14px">
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Organisation</td><td><strong>#{org.name}</strong></td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Plan</td><td><strong>#{plan.humanize}</strong></td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Stripe Sub ID</td><td>#{sub.stripe_subscription_id}</td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Fin de période</td><td>#{sub.current_period_end&.strftime('%d/%m/%Y')}</td></tr>
            <tr><td style="padding:4px 12px 4px 0;color:#6b7280">Date</td><td>#{Time.current.strftime('%d/%m/%Y %H:%M')}</td></tr>
          </table>
        HTML
      }
    end
  rescue StandardError => e
    Rails.logger.warn "[Webhook:SubscriptionUpdated] Admin notification failed: #{e.message}"
  end

  def resolve_plan(stripe_sub)
    price = stripe_sub.items&.data&.first&.price
    return nil unless price

    # Priorité 1 : lookup_key configuré sur le prix Stripe
    return PRICE_PLAN_MAP[price.lookup_key] if price.lookup_key.present? && PRICE_PLAN_MAP[price.lookup_key]

    # Priorité 2 : match par Price ID via env vars
    ENV.each do |key, value|
      next unless key.start_with?("STRIPE_PRICE_")
      return key.sub("STRIPE_PRICE_", "").downcase if value == price.id
    end

    nil
  end
end
