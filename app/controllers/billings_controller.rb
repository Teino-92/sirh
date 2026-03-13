# frozen_string_literal: true

class BillingsController < ApplicationController
  skip_before_action :check_trial_expired!

  before_action :authenticate_employee!
  before_action :set_organization
  before_action :authorize_billing

  # GET /billing — page principale (tunnel post-trial ou gestion abonnement actif)
  def show
    @billing      = BillingService.new(@org)
    @subscription = @org.subscription
  end

  # POST /billing/checkout — crée une Stripe Checkout Session
  def create_checkout
    plan = permitted_plan(params[:plan])
    return redirect_to billing_path, alert: "Plan invalide." unless plan

    result = CheckoutService.new(
      organization: @org,
      plan:         plan,
      success_url:  success_billing_url(host: ENV.fetch("APP_HOST", "izi-rh.com"), protocol: "https"),
      cancel_url:   billing_url(host: ENV.fetch("APP_HOST", "izi-rh.com"), protocol: "https")
    ).call

    if result.success?
      redirect_to result.checkout_url, allow_other_host: true
    else
      redirect_to billing_path, alert: "Erreur lors de la création du paiement : #{result.error}"
    end
  end

  # GET /billing/success — retour Stripe Checkout
  def success
    @billing = BillingService.new(@org)
  end

  # POST /billing/upgrade — upgrade Essentiel → Pro (self-service)
  def upgrade
    billing = BillingService.new(@org)

    unless billing.can_self_upgrade?
      return redirect_to billing_path, alert: "Cet upgrade n'est pas disponible en self-service."
    end

    result = SubscriptionUpgradeService.new(
      organization: @org,
      target_plan:  "sirh_pro"
    ).call

    if result.success?
      redirect_to billing_path, notice: "Votre abonnement a été mis à niveau vers SIRH Pro."
    else
      redirect_to billing_path, alert: "Erreur lors de l'upgrade : #{result.error}"
    end
  end

  # POST /billing/request_upgrade — demande OS → SIRH (modal de contact)
  def request_upgrade
    billing = BillingService.new(@org)

    unless billing.upgrade_requires_contact?
      return redirect_to billing_path, alert: "Cette action n'est pas disponible."
    end

    contact = params.permit(:contact_name, :contact_email, :contact_message)

    if contact[:contact_name].blank? || contact[:contact_email].blank?
      return redirect_to billing_path, alert: "Veuillez renseigner votre nom et votre email."
    end

    result = SubscriptionUpgradeService.new(
      organization:    @org,
      target_plan:     "sirh_essential",
      contact_name:    contact[:contact_name],
      contact_email:   contact[:contact_email],
      contact_message: contact[:contact_message]
    ).call

    if result.success?
      redirect_to billing_path, notice: "Votre demande a été transmise. Notre équipe vous contactera sous 24h."
    else
      redirect_to billing_path, alert: result.error
    end
  end

  # DELETE /billing/cancel — annuler l'abonnement (bloqué pendant l'engagement)
  def cancel
    sub = @org.subscription
    return redirect_to billing_path, alert: "Aucun abonnement actif." unless sub&.active?

    unless sub.can_cancel?
      months = sub.commitment_months_remaining
      return redirect_to billing_path,
             alert: "Résiliation impossible : engagement actif encore #{months} mois."
    end

    Stripe::Subscription.update(sub.stripe_subscription_id, cancel_at_period_end: true)
    sub.update!(cancel_at_period_end: true)

    redirect_to billing_path, notice: "Votre abonnement sera résilié à la fin de la période en cours."
  rescue Stripe::StripeError => e
    redirect_to billing_path, alert: "Erreur Stripe : #{e.message}"
  end

  private

  def set_organization
    # Eager-load subscription pour éviter le N+1 dans check_trial_expired! et BillingService
    @org = Organization.includes(:subscription).find(current_employee.organization_id)
  end

  def authorize_billing
    authorize @org, policy_class: BillingPolicy
  end

  def permitted_plan(plan)
    allowed = %w[manager_os sirh_essential sirh_pro]
    allowed.include?(plan.to_s) ? plan.to_s : nil
  end
end
