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
    "manager_os_monthly"     => "manager_os",
    "sirh_essential_monthly" => "sirh_essential",
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

    sub.update!(attrs)

    Rails.logger.info "[Webhook:SubscriptionUpdated] Sub #{stripe_sub.id} → status=#{new_status} plan=#{new_plan || sub.plan}"
  end

  private

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
