# frozen_string_literal: true

# CheckoutService — crée une Stripe Checkout Session pour la souscription initiale.
# Engagement 1 an : abonnement mensuel Stripe + commitment_end_at stocké via webhook.
# La résiliation côté app est bloquée par Subscription#can_cancel? jusqu'à commitment_end_at.

class CheckoutService
  Result = Struct.new(:success?, :checkout_url, :error)

  # Lookup keys Stripe — indépendants des price IDs, portables entre test et prod
  STRIPE_LOOKUP_KEYS = {
    "manager_os"     => "manager_os_monthly",
    "sirh_essential" => "sirh_essentiel_monthly",
    "sirh_pro"       => "sirh_pro_monthly"
  }.freeze

  def initialize(organization:, plan:, success_url:, cancel_url:)
    @org         = organization
    @plan        = plan
    @success_url = success_url
    @cancel_url  = cancel_url
  end

  def call
    price_id = resolve_price_id
    return Result.new(false, nil, "Plan inconnu : #{@plan}") if price_id.blank?

    customer_id = find_or_create_stripe_customer
    session     = create_checkout_session(customer_id, price_id)

    Result.new(true, session.url, nil)
  rescue Stripe::StripeError => e
    Rails.logger.error "[CheckoutService] Stripe error: #{e.message}"
    Result.new(false, nil, e.message)
  end

  private

  def resolve_price_id
    # 1. Env var directe (STRIPE_PRICE_MANAGER_OS, etc.) — priorité absolue
    env_key = "STRIPE_PRICE_#{@plan.upcase}"
    return ENV[env_key] if ENV[env_key].present?

    # 2. Lookup key Stripe (nécessite que les prix soient créés avec ces lookup keys)
    lookup_key = STRIPE_LOOKUP_KEYS[@plan]
    return nil if lookup_key.blank?

    prices = Stripe::Price.list(lookup_keys: [lookup_key], expand: ["data.product"])
    prices.data.first&.id
  rescue Stripe::StripeError => e
    Rails.logger.error "[CheckoutService] Cannot resolve price for #{@plan}: #{e.message}"
    nil
  end

  # Atomique : row lock sur l'org pour éviter la création de plusieurs Stripe customers
  def find_or_create_stripe_customer
    sub = @org.subscription
    return sub.stripe_customer_id if sub&.stripe_customer_id.present?

    ActiveRecord::Base.transaction do
      # Recharge + lock pour sérialiser les appels concurrents
      locked_org = Organization.lock.find(@org.id)
      sub = Subscription.find_by(organization_id: locked_org.id)

      # Double-check après lock : un autre thread a peut-être déjà créé le customer
      return sub.stripe_customer_id if sub&.stripe_customer_id.present?

      customer = Stripe::Customer.create(
        name:     locked_org.name,
        metadata: { organization_id: locked_org.id }
      )

      if sub
        sub.update!(stripe_customer_id: customer.id)
      else
        Subscription.create!(
          organization:       locked_org,
          stripe_customer_id: customer.id,
          plan:               @plan,
          status:             "incomplete"
        )
      end

      customer.id
    end
  end

  def create_checkout_session(customer_id, price_id)
    subscription_data = {
      metadata: {
        organization_id:   @org.id,
        plan:              @plan,
        commitment_months: 12
      }
    }

    # Si l'org est encore en trial avec plus de 60s restantes, ancrer la
    # facturation à la fin du trial — la CB est enregistrée maintenant,
    # le premier paiement se déclenche à trial_ends_at.
    if @org.trial_active? && @org.trial_ends_at.to_i > Time.current.to_i + 60
      subscription_data[:trial_end] = @org.trial_ends_at.to_i
    end

    Stripe::Checkout::Session.create(
      customer:             customer_id,
      mode:                 "subscription",
      line_items:           [{ price: price_id, quantity: 1 }],
      subscription_data:    subscription_data,
      payment_method_types: ["card"],
      locale:               "fr",
      success_url:          @success_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url:           @cancel_url,
      metadata: {
        organization_id: @org.id,
        plan:            @plan
      }
    )
  end
end
