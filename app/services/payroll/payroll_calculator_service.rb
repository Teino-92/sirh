# frozen_string_literal: true

module Payroll
  # Computes a gross pay estimate for one employee and one calendar month.
  #
  # This is an INTERNAL estimative tool — not a substitute for Silae/ADP.
  # It never calculates net pay or social contributions.
  #
  # Inputs:
  #   employee  [Employee]  — must have work_schedule and gross_salary_cents
  #   period    [Date]      — any date within the target month
  #
  # Optional keyword args (for bulk-export N+1 avoidance):
  #   preloaded_time_entries   [Array<TimeEntry>]   — already filtered for the month
  #   preloaded_leave_requests [Array<LeaveRequest>] — already filtered for the month
  #
  # Output hash:
  #   base_salary          Float  — contractual gross prorated for part_time_rate
  #   worked_hours         Float  — sum of validated time entries (net of breaks)
  #   contractual_hours    Float  — theoretical monthly hours from work_schedule
  #   overtime_25          Float  — overtime hours at +25% rate
  #   overtime_50          Float  — overtime hours at +50% rate
  #   overtime_bonus       Float  — euro amount for overtime majoration
  #   leave_days_cp        Float
  #   leave_days_rtt       Float
  #   leave_days_sick      Float
  #   leave_deduction      Float  — euro deduction for unpaid leave (Sans_Solde)
  #   gross_total          Float  — estimated gross total
  #   note                 String
  class PayrollCalculatorService
    WORKING_DAYS_PER_MONTH = 22.0   # French average
    LEGAL_DAILY_HOURS      = 7.0    # Reference for overtime threshold
    WEEKS_PER_MONTH        = 4.33   # Average weeks per month

    # Overtime thresholds (Code du travail art. L3121-22):
    # First 8 hours/week over threshold → +25%
    # Beyond → +50%
    OVERTIME_25_WEEKLY_CAP = 8.0

    def initialize(employee, period, preloaded_time_entries: nil, preloaded_leave_requests: nil)
      @employee                 = employee
      @period                   = period.beginning_of_month
      @preloaded_time_entries   = preloaded_time_entries
      @preloaded_leave_requests = preloaded_leave_requests
    end

    def call
      schedule         = @employee.work_schedule
      weekly_hours     = schedule&.weekly_hours&.to_f || 35.0
      part_time_rate   = @employee.part_time_rate&.to_f || 1.0
      gross            = @employee.gross_salary / part_time_rate  # full-time equivalent

      contractual_hours = monthly_contractual_hours(weekly_hours)
      worked_hours      = monthly_worked_hours
      delta             = worked_hours - contractual_hours

      overtime_25, overtime_50 = compute_overtime(delta)
      hourly_rate               = contractual_hours > 0 ? (gross * part_time_rate) / contractual_hours : 0.0
      overtime_bonus            = (overtime_25 * hourly_rate * 1.25) + (overtime_50 * hourly_rate * 1.50)

      cp_days, rtt_days, sick_days, sans_solde_days = leave_days_by_type

      # Sans Solde → salary deduction (pro-rata daily)
      daily_rate      = (gross * part_time_rate) / WORKING_DAYS_PER_MONTH
      leave_deduction = sans_solde_days * daily_rate

      gross_total = (gross * part_time_rate) + overtime_bonus - leave_deduction

      {
        base_salary:       (gross * part_time_rate).round(2),
        worked_hours:      worked_hours.round(2),
        contractual_hours: contractual_hours.round(2),
        overtime_25:       overtime_25.round(2),
        overtime_50:       overtime_50.round(2),
        overtime_bonus:    overtime_bonus.round(2),
        leave_days_cp:     cp_days,
        leave_days_rtt:    rtt_days,
        leave_days_sick:   sick_days,
        leave_deduction:   leave_deduction.round(2),
        gross_total:       gross_total.round(2),
        note:              "Estimatif — confirmer avec logiciel de paie"
      }
    end

    private

    def monthly_contractual_hours(weekly_hours)
      working_days = business_days_in_month
      (weekly_hours / 5.0) * working_days
    end

    def monthly_worked_hours
      entries = if @preloaded_time_entries
                  @preloaded_time_entries
                else
                  @employee.time_entries
                           .validated
                           .where('clock_in >= ? AND clock_in < ?', @period, @period.next_month)
                           .to_a
                end

      entries.sum { |e| [e.duration_minutes.to_i - e.break_duration_minutes.to_i, 0].max } / 60.0
    end

    # Splits delta into overtime_25 and overtime_50 buckets.
    # Approximates weekly distribution from monthly totals.
    def compute_overtime(delta)
      return [0.0, 0.0] if delta <= 0

      # Monthly cap for +25% = 8h/week × weeks_in_month
      cap_25 = OVERTIME_25_WEEKLY_CAP * weeks_in_month
      ot_25  = [delta, cap_25].min
      ot_50  = [delta - cap_25, 0.0].max

      [ot_25, ot_50]
    end

    def leave_days_by_type
      leaves = if @preloaded_leave_requests
                 @preloaded_leave_requests
               else
                 @employee.leave_requests
                          .where(status: %w[approved auto_approved])
                          .where('start_date <= ? AND end_date >= ?', @period.end_of_month, @period)
                          .to_a
               end

      cp         = leaves.select { |l| l.leave_type == 'CP' }.sum(&:days_count).to_f
      rtt        = leaves.select { |l| l.leave_type == 'RTT' }.sum(&:days_count).to_f
      sick       = leaves.select { |l| l.leave_type == 'Maladie' }.sum(&:days_count).to_f
      sans_solde = leaves.select { |l| l.leave_type == 'Sans_Solde' }.sum(&:days_count).to_f

      [cp, rtt, sick, sans_solde]
    end

    def business_days_in_month
      first = @period
      last  = @period.end_of_month
      (first..last).count { |d| d.on_weekday? }
    end

    def weeks_in_month
      business_days_in_month / 5.0
    end
  end
end
