# frozen_string_literal: true

# BillingService — source of truth pour les feature gates.
# Toujours appeler BillingService.new(org).can?(:feature) depuis les controllers/views.
# Ne jamais éparpiller les checks de plan dans le code.

class BillingService
  PLAN_FEATURES = {
    manager_os: %i[
      onboarding one_on_ones objectives training dashboard_manager
    ],
    sirh_essential: %i[
      onboarding one_on_ones objectives training dashboard_manager
      time_tracking leave_management team_planning payroll_exports
    ],
    sirh_pro: %i[
      onboarding one_on_ones objectives training dashboard_manager
      time_tracking leave_management team_planning payroll_exports
      payroll_analytics hr_ai geolocation audit_log api_mobile
    ]
  }.freeze

  def initialize(organization)
    @org = organization
    @subscription = organization.subscription
  end

  def can?(feature)
    return false unless billing_active?
    PLAN_FEATURES.fetch(current_plan, []).include?(feature.to_sym)
  end

  def current_plan
    return :manager_os    if @subscription&.manager_os?
    return :sirh_essential if @subscription&.sirh_essential?
    return :sirh_pro      if @subscription&.sirh_pro?

    # Fallback sur le champ plan de l'org (legacy / trial)
    case @org.plan
    when "manager_os" then :manager_os
    when "sirh"       then :sirh_essential
    else :manager_os
    end
  end

  def billing_active?
    # Trial encore valide
    return true if @org.trial_active?
    # Abonnement actif
    return true if @subscription&.active?
    false
  end

  def needs_subscription?
    @org.trial_expired? && (@subscription.nil? || @subscription.canceled?)
  end

  def can_upgrade_to_pro?
    @subscription&.sirh_essential? && @subscription&.active?
  end

  def can_self_upgrade?
    # Essentiel → Pro uniquement en self-service
    can_upgrade_to_pro?
  end

  def upgrade_requires_contact?
    # OS → SIRH nécessite intervention admin
    @subscription&.manager_os? || @org.plan == "manager_os"
  end
end
