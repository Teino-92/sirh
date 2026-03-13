# frozen_string_literal: true

class PaymentFailedHandler
  def call(event)
    invoice       = event.data.object
    stripe_sub_id = invoice.respond_to?(:subscription) ? invoice.subscription : nil
    stripe_sub_id ||= invoice.parent&.subscription_details&.subscription
    return if stripe_sub_id.blank?

    sub = Subscription.find_by(stripe_subscription_id: stripe_sub_id)
    return unless sub

    sub.update!(status: "past_due", last_webhook_at: Time.current)

    # Charger org + admin en une seule query pour éviter le N+1
    org = Organization.includes(:employees).find(sub.organization_id)
    org_admin = org.employees.find { |e| e.role.in?(%w[hr admin]) }
    BillingMailer.payment_failed(org, org_admin).deliver_later if org_admin

    Rails.logger.warn "[Webhook:PaymentFailed] Org #{sub.organization_id} payment failed"
  end
end
