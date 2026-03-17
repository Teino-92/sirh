# frozen_string_literal: true

# Façade — French Legal Compliance Engine for Leave Policies.
# Implements French labor law (Code du travail) via four focused services:
#   - LeavePolicySettings     — cascading rule resolution
#   - LeaveAccrualCalculator  — CP/RTT accrual calculations and persistence
#   - LeaveRequestValidator   — request validation against law and org policies
#   - FrenchCalendar          — working day calculation and public holidays
#
# All callers use LeavePolicyEngine.new(employee) — interface unchanged.
class LeavePolicyEngine
  # Expose LEGAL_DEFAULTS for backward compatibility (specs reference it)
  LEGAL_DEFAULTS = LeavePolicySettings::LEGAL_DEFAULTS

  attr_reader :employee, :organization

  def initialize(employee)
    @employee     = employee
    @organization = employee.organization
    @settings     = LeavePolicySettings.new(employee)
    @accrual      = LeaveAccrualCalculator.new(employee, @settings)
    @validator    = LeaveRequestValidator.new(employee, @settings)
    @calendar     = FrenchCalendar.new(region: @organization.legal_region)
  end

  # ── Settings ────────────────────────────────────────────────────────────────

  def get_setting(key)
    @settings.get(key)
  end

  # ── Accrual ─────────────────────────────────────────────────────────────────

  def calculate_cp_balance(as_of_date: Date.current)
    @accrual.calculate_cp_balance(as_of_date: as_of_date)
  end

  def calculate_rtt_accrual(worked_hours, period_weeks: 1)
    @accrual.calculate_rtt_accrual(worked_hours, period_weeks: period_weeks)
  end

  def accrue_monthly_cp!
    @accrual.accrue_monthly_cp!
  end

  def accrue_rtt!(worked_hours, period_weeks: 1)
    @accrual.accrue_rtt!(worked_hours, period_weeks: period_weeks)
  end

  def cp_expiration_date(year = Date.current.year)
    @accrual.cp_expiration_date(year)
  end

  # ── Validation ──────────────────────────────────────────────────────────────

  def validate_leave_request(leave_request)
    @validator.validate(leave_request)
  end

  def can_auto_approve?(leave_request)
    @validator.can_auto_approve?(leave_request)
  end

  # ── Calendar ────────────────────────────────────────────────────────────────

  def calculate_working_days(start_date, end_date)
    @calendar.working_days_between(start_date, end_date)
  end

  private

  # Delegated for backward compatibility with specs that use send(:private_method)
  def easter_sunday(year)       = @calendar.send(:easter_sunday, year)
  def easter_monday(year)       = @calendar.send(:easter_monday, year)
  def ascension_day(year)       = @calendar.send(:ascension_day, year)
  def whit_monday(year)         = @calendar.send(:whit_monday, year)
  def french_holidays_for_year(year) = @calendar.send(:holidays_for_year, year)
  def part_time_employee?       = @accrual.send(:part_time?)
  def part_time_ratio           = @accrual.send(:part_time_ratio)
  def monthly_cp_accrual        = @accrual.send(:monthly_cp_accrual)
end
