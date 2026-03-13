# frozen_string_literal: true

class SubscriptionDeletedHandler
  def call(event)
    stripe_sub = event.data.object
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    return unless sub

    if sub.canceled?
      Rails.logger.info "[Webhook:SubscriptionDeleted] Already canceled #{stripe_sub.id}, skipping"
      return
    end

    sub.update!(
      status:          "canceled",
      last_webhook_at: Time.current
    )

    Rails.logger.info "[Webhook:SubscriptionDeleted] Subscription #{stripe_sub.id} canceled for org #{sub.organization_id}"
  end
end
