# frozen_string_literal: true

# Handles CP and RTT accrual calculations and persistence.
class LeaveAccrualCalculator
  def initialize(employee, settings)
    @employee     = employee
    @organization = employee.organization
    @settings     = settings
  end

  def calculate_cp_balance(as_of_date: Date.current)
    months = months_worked(@employee.start_date, as_of_date)
    base   = [months * @settings.get(:cp_acquisition_rate), @settings.get(:cp_max_annual)].min
    part_time? ? base * part_time_ratio : base
  end

  def calculate_rtt_accrual(worked_hours, period_weeks: 1)
    return 0 unless @organization.rtt_enabled?

    weekly_hours  = worked_hours / period_weeks
    overtime      = [weekly_hours - @settings.get(:rtt_calculation_threshold), 0].max
    (overtime / 7.0) * period_weeks
  end

  def accrue_monthly_cp!
    cp_balance = find_or_init_balance('CP')
    amount     = monthly_cp_accrual
    next_expiry = cp_expiration_date(Date.current.year + 1)

    cp_balance.update!(
      balance:           cp_balance.balance + amount,
      accrued_this_year: cp_balance.accrued_this_year + amount,
      expires_at:        next_expiry
    )
    amount
  end

  def accrue_rtt!(worked_hours, period_weeks: 1)
    return 0 unless @organization.rtt_enabled?

    amount = calculate_rtt_accrual(worked_hours, period_weeks: period_weeks)
    return 0 if amount.zero?

    rtt_balance = find_or_init_balance('RTT')
    rtt_balance.update!(
      balance:           rtt_balance.balance + amount,
      accrued_this_year: rtt_balance.accrued_this_year + amount
    )
    amount
  end

  def cp_expiration_date(year = Date.current.year)
    Date.new(year, @settings.get(:cp_expiry_month), @settings.get(:cp_expiry_day))
  end

  private

  def months_worked(start_date, end_date)
    ((end_date.year - start_date.year) * 12) + (end_date.month - start_date.month)
  end

  def part_time?
    @employee.work_schedule&.weekly_hours.to_f < @settings.get(:legal_work_week_hours)
  end

  def part_time_ratio
    return 1.0 unless @employee.work_schedule
    @employee.work_schedule.weekly_hours.to_f / @settings.get(:legal_work_week_hours)
  end

  def monthly_cp_accrual
    rate = @settings.get(:cp_acquisition_rate)
    part_time? ? rate * part_time_ratio : rate
  end

  def find_or_init_balance(leave_type)
    @employee.leave_balances.find_or_create_by(leave_type: leave_type) do |b|
      b.balance = 0
      b.accrued_this_year = 0
      b.used_this_year    = 0
    end
  end
end
