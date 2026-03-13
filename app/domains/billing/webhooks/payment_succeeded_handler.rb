# frozen_string_literal: true

class PaymentSucceededHandler
  def call(event)
    invoice       = event.data.object
    # Stripe API 2026-02-25+: subscription moved to parent.subscription_details.subscription
    stripe_sub_id = invoice.respond_to?(:subscription) ? invoice.subscription : nil
    stripe_sub_id ||= invoice.parent&.subscription_details&.subscription
    return if stripe_sub_id.blank?

    sub = Subscription.find_by(stripe_subscription_id: stripe_sub_id)
    return unless sub

    if sub.past_due?
      sub.update!(status: "active", last_webhook_at: Time.current)
      Rails.logger.info "[Webhook:PaymentSucceeded] Org #{sub.organization_id} reactivated after past_due"
    else
      sub.touch(:last_webhook_at)
    end
  end
end
