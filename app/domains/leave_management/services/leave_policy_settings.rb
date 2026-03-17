# frozen_string_literal: true

# Resolves leave policy settings using a cascading priority chain:
#   1. Employee contract overrides (contrat individuel)
#   2. Organization settings (accord d'entreprise)
#   3. French legal defaults (Code du travail)
#
# Note: convention_collective (IDCC) is stored on Employee and Organization for payroll
# exports only (Silae/PayFit). It does not drive leave policy rules — implementing
# per-CCN rule tables is out of scope (400+ conventions, specialist data source required).
class LeavePolicySettings
  LEGAL_DEFAULTS = {
    cp_acquisition_rate: 2.5,
    cp_acquisition_period_months: 12,
    cp_max_annual: 30,
    cp_expiry_month: 5,
    cp_expiry_day: 31,
    minimum_consecutive_leave_days: 10,
    legal_work_week_hours: 35,
    rtt_calculation_threshold: 35,
    auto_approve_threshold_days: 15,
    auto_approve_max_request_days: 2
  }.freeze

  def initialize(employee)
    @employee     = employee
    @organization = employee.organization
  end

  def get(key)
    if @employee.respond_to?(:contract_overrides) && @employee.contract_overrides.present?
      return @employee.contract_overrides[key.to_s] if @employee.contract_overrides.key?(key.to_s)
    end

    return @organization.settings[key.to_s] if @organization.settings.key?(key.to_s)

    LEGAL_DEFAULTS[key]
  end
end
