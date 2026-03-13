# frozen_string_literal: true

class PaymentSucceededHandler
  def call(event)
    invoice       = event.data.object
    stripe_sub_id = invoice.subscription
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
