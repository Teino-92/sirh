# frozen_string_literal: true

# StripeWebhooksController — reçoit les événements Stripe.
# Hérite de ActionController::Base (pas ApplicationController) :
# - Pas de before_action Devise
# - Pas de Pundit
# - Pas d'ActsAsTenant
# La sécurité repose entièrement sur la vérification de signature Stripe dans WebhookProcessor.

class StripeWebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def create
    payload   = request.body.read
    signature = request.env["HTTP_STRIPE_SIGNATURE"]

    if signature.blank?
      Rails.logger.warn "[StripeWebhook] Missing Stripe-Signature header"
      return head :bad_request
    end

    result = WebhookProcessor.new(payload: payload, signature: signature).call

    if result.success?
      head :ok
    else
      # 400 pour les signatures invalides (Stripe ne retry pas les 400 sur vérif signature)
      # 500 pour les erreurs internes (Stripe retry automatiquement)
      Rails.logger.warn "[StripeWebhook] Processing failed: #{result.error}"
      head :bad_request
    end
  end
end
