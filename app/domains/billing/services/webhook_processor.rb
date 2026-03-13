# frozen_string_literal: true

# WebhookProcessor — point d'entrée unique pour tous les webhooks Stripe.
# Vérifie la signature, dispatche vers le bon handler, garantit l'idempotence.

class WebhookProcessor
  HANDLED_EVENTS = %w[
    checkout.session.completed
    customer.subscription.created
    customer.subscription.updated
    customer.subscription.deleted
    invoice.payment_succeeded
    invoice.payment_failed
  ].freeze

  Result = Struct.new(:success?, :error)

  def initialize(payload:, signature:)
    @payload   = payload
    @signature = signature
  end

  def call
    event = verify_signature
    return Result.new(false, "Signature invalide") unless event

    return Result.new(true, nil) unless HANDLED_EVENTS.include?(event.type)

    handler = handler_for(event)
    handler.call(event)

    Result.new(true, nil)
  rescue Stripe::SignatureVerificationError => e
    Rails.logger.warn "[Webhook] Signature verification failed: #{e.message}"
    Result.new(false, "Signature invalide")
  rescue => e
    Rails.logger.error "[Webhook] Error: #{e.class} — #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    # Retourner success: false → 400 côté controller → Stripe retry (comportement souhaité)
    Result.new(false, e.message)
  end

  private

  def verify_signature
    webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

    unless webhook_secret.present?
      Rails.logger.fatal "[Webhook] STRIPE_WEBHOOK_SECRET not configured — rejecting all webhooks"
      raise KeyError, "STRIPE_WEBHOOK_SECRET must be set"
    end

    Stripe::Webhook.construct_event(@payload, @signature, webhook_secret)
  end

  def handler_for(event)
    case event.type
    when "checkout.session.completed"
      CheckoutCompletedHandler.new
    when "customer.subscription.created", "customer.subscription.updated"
      SubscriptionUpdatedHandler.new
    when "customer.subscription.deleted"
      SubscriptionDeletedHandler.new
    when "invoice.payment_succeeded"
      PaymentSucceededHandler.new
    when "invoice.payment_failed"
      PaymentFailedHandler.new
    end
  end
end
