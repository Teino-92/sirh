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

  def call(event)
    stripe_sub = event.data.object
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)

    unless sub
      Rails.logger.warn "[Webhook:SubscriptionUpdated] No subscription found for #{stripe_sub.id}"
      return
    end

    new_status = STRIPE_STATUS_MAP.fetch(stripe_sub.status, "active")

    sub.update!(
      status:               new_status,
      current_period_end:   Time.at(stripe_sub.current_period_end),
      cancel_at_period_end: stripe_sub.cancel_at_period_end,
      last_webhook_at:      Time.current
    )

    Rails.logger.info "[Webhook:SubscriptionUpdated] Sub #{stripe_sub.id} → status=#{new_status}"
  end
end
