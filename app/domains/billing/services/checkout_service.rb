# frozen_string_literal: true

# CheckoutService — crée une Stripe Checkout Session pour la souscription initiale.
# Engagement 1 an : abonnement mensuel Stripe + commitment_end_at stocké via webhook.
# La résiliation côté app est bloquée par Subscription#can_cancel? jusqu'à commitment_end_at.

class CheckoutService
  Result = Struct.new(:success?, :checkout_url, :error)

  STRIPE_PRICE_IDS = {
    "manager_os"     => ENV["STRIPE_PRICE_MANAGER_OS"],
    "sirh_essential" => ENV["STRIPE_PRICE_SIRH_ESSENTIAL"],
    "sirh_pro"       => ENV["STRIPE_PRICE_SIRH_PRO"]
  }.freeze

  def initialize(organization:, plan:, success_url:, cancel_url:)
    @org         = organization
    @plan        = plan
    @success_url = success_url
    @cancel_url  = cancel_url
  end

  def call
    price_id = STRIPE_PRICE_IDS[@plan]
    return Result.new(false, nil, "Plan inconnu : #{@plan}") if price_id.blank?

    customer_id = find_or_create_stripe_customer
    session     = create_checkout_session(customer_id, price_id)

    Result.new(true, session.url, nil)
  rescue Stripe::StripeError => e
    Rails.logger.error "[CheckoutService] Stripe error: #{e.message}"
    Result.new(false, nil, e.message)
  end

  private

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
    Stripe::Checkout::Session.create(
      customer:   customer_id,
      mode:       "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      subscription_data: {
        metadata: {
          organization_id:   @org.id,
          plan:              @plan,
          commitment_months: 12
        }
      },
      payment_method_types: ["card", "sepa_debit"],
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
