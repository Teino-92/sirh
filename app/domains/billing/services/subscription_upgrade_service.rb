# frozen_string_literal: true

# SubscriptionUpgradeService — gère les upgrades de plan.
#
# Cas 1 (self-service) : Essentiel → Pro
#   Mise à jour immédiate via Stripe API (proration automatique).
#
# Cas 2 (admin requis) : Manager OS → SIRH
#   Passe le status en "upgrade_pending" + notifie les admins.
#   L'admin finalise depuis le dashboard Rails ou Stripe.

class SubscriptionUpgradeService
  Result = Struct.new(:success?, :error)

  UPGRADE_PRICE = {
    "sirh_pro" => ENV["STRIPE_PRICE_SIRH_PRO"]
  }.freeze

  def initialize(organization:, target_plan:)
    @org         = organization
    @sub         = organization.subscription
    @target_plan = target_plan
  end

  def call
    return Result.new(false, "Aucun abonnement actif") unless @sub&.active?

    case @target_plan
    when "sirh_pro"
      upgrade_to_pro
    when "sirh_essential", "sirh"
      request_admin_upgrade
    else
      Result.new(false, "Plan cible invalide")
    end
  end

  private

  # Self-service : Essentiel → Pro via Stripe API
  def upgrade_to_pro
    unless @sub.sirh_essential?
      return Result.new(false, "Upgrade Pro uniquement disponible depuis le plan Essentiel")
    end

    price_id = UPGRADE_PRICE["sirh_pro"]
    return Result.new(false, "Prix Stripe Pro non configuré") if price_id.blank?

    unless @sub.stripe_subscription_id.present?
      return Result.new(false, "Abonnement Stripe non lié — contactez le support")
    end

    stripe_sub = Stripe::Subscription.retrieve(@sub.stripe_subscription_id)

    unless stripe_sub.items.data.any?
      return Result.new(false, "Abonnement Stripe invalide — contactez le support")
    end

    item_id = stripe_sub.items.data.first.id

    Stripe::Subscription.update(
      @sub.stripe_subscription_id,
      items: [{ id: item_id, price: price_id }],
      proration_behavior: "always_invoice"
    )

    @sub.update!(plan: "sirh_pro")
    @org.update!(plan: "sirh")

    Result.new(true, nil)
  rescue Stripe::StripeError => e
    Rails.logger.error "[UpgradeService] Stripe error: #{e.message}"
    Result.new(false, e.message)
  end

  # Upgrade OS → SIRH : nécessite intervention admin
  def request_admin_upgrade
    unless @sub.manager_os?
      return Result.new(false, "Cette demande ne s'applique qu'au plan Manager OS")
    end

    @sub.update!(status: "upgrade_pending")

    # Notifier les admins via email
    AdminUpgradeMailer.upgrade_requested(@org).deliver_later

    Result.new(true, nil)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(false, e.message)
  end
end
