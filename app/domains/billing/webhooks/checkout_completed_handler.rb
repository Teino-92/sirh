# frozen_string_literal: true

class CheckoutCompletedHandler
  def call(event)
    session = event.data.object
    return unless session.mode == "subscription"

    org_id = session.metadata["organization_id"]&.to_i
    plan   = session.metadata["plan"]
    org    = Organization.find_by(id: org_id)

    unless org
      Rails.logger.error "[Webhook:CheckoutCompleted] Organization #{org_id} not found"
      return
    end

    # Transaction + row lock pour garantir l'atomicité face aux webhooks dupliqués
    ActiveRecord::Base.transaction do
      # Lock sur l'org pour sérialiser les webhooks concurrents de la même org
      org.lock!

      sub = Subscription.find_by(organization_id: org.id) || Subscription.new(organization: org)

      # Idempotence : déjà traité pour cette session
      if sub.persisted? && sub.stripe_checkout_session_id == session.id && sub.active?
        Rails.logger.info "[Webhook:CheckoutCompleted] Duplicate webhook for session #{session.id}, skipping"
        return
      end

      commitment_end = 12.months.from_now

      sub.assign_attributes(
        stripe_customer_id:         session.customer,
        stripe_subscription_id:     session.subscription,
        stripe_checkout_session_id: session.id,
        plan:                       plan,
        status:                     "active",
        commitment_end_at:          commitment_end,
        last_webhook_at:            Time.current
      )
      sub.save!

      org_plan = plan.start_with?("sirh") ? "sirh" : "manager_os"
      org.update!(plan: org_plan)

      Rails.logger.info "[Webhook:CheckoutCompleted] Org #{org_id} subscribed to #{plan}, commitment until #{commitment_end.to_date}"
    end
  end
end
