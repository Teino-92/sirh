# frozen_string_literal: true

module LeaveManagement
  module Services
    # French Legal Compliance Engine for Leave Policies
    # Implements French labor law (Code du travail) for leave management
    class LeavePolicyEngine
      # French legal constants
      CP_ACQUISITION_RATE = 2.5 # days per month (30 days / 12 months)
      CP_ACQUISITION_PERIOD_MONTHS = 12
      CP_MAX_ANNUAL = 30 # 5 weeks * 6 days (French week counting)
      CP_EXPIRY_MONTH = 5 # May
      CP_EXPIRY_DAY = 31
      MINIMUM_CONSECUTIVE_LEAVE_DAYS = 10 # 2 weeks mandatory
      LEGAL_WORK_WEEK_HOURS = 35
      RTT_CALCULATION_THRESHOLD = 35 # hours per week

      attr_reader :employee, :organization

      def initialize(employee)
        @employee = employee
        @organization = employee.organization
      end

      # Calculate CP balance based on tenure and worked time
      def calculate_cp_balance(as_of_date: Date.current)
        months_worked = calculate_months_worked(employee.start_date, as_of_date)
        base_accrual = [months_worked * CP_ACQUISITION_RATE, CP_MAX_ANNUAL].min

        # Adjust for part-time if applicable
        if part_time_employee?
          base_accrual * part_time_ratio
        else
          base_accrual
        end
      end

      # Calculate RTT accrual based on worked hours over 35h
      def calculate_rtt_accrual(worked_hours, period_weeks: 1)
        return 0 unless organization.rtt_enabled?

        weekly_hours = worked_hours / period_weeks
        overtime_hours = [weekly_hours - RTT_CALCULATION_THRESHOLD, 0].max

        # RTT = (hours over 35h) / 7 * number of weeks
        # French law: 1 RTT day ≈ 7 hours of overtime
        (overtime_hours / 7.0) * period_weeks
      end

      # Validate leave request against French labor law
      def validate_leave_request(leave_request)
        errors = []

        # Check balance
        unless sufficient_balance?(leave_request)
          errors << "Solde insuffisant pour #{leave_request.leave_type}"
        end

        # Check consecutive leave requirement for CP
        if leave_request.leave_type == 'CP' && in_summer_period?(leave_request)
          unless meets_consecutive_requirement?(leave_request)
            errors << "Vous devez prendre au moins #{MINIMUM_CONSECUTIVE_LEAVE_DAYS} jours consécutifs entre le 1er mai et le 31 octobre"
          end
        end

        # Check CP expiration
        if leave_request.leave_type == 'CP'
          if requesting_expired_cp?(leave_request)
            errors << "Ces congés payés ont expiré. Les CP doivent être pris avant le 31 mai."
          end
        end

        # Check team conflicts
        if leave_request.conflicts_with_team?
          errors << "Conflit avec les congés d'un autre membre de l'équipe"
        end

        errors
      end

      # Calculate working days between two dates (excluding weekends and French holidays)
      def calculate_working_days(start_date, end_date)
        days = 0
        current_date = start_date

        while current_date <= end_date
          days += 1 unless weekend?(current_date) || french_holiday?(current_date)
          current_date += 1.day
        end

        days
      end

      # Check if leave request can be auto-approved
      def can_auto_approve?(leave_request)
        return false unless leave_request.leave_type == 'CP'

        # Auto-approve if:
        # 1. Employee has sufficient balance (15+ days remaining)
        # 2. Request is for 1-2 days only
        # 3. No team conflicts
        # 4. Not during blackout period (company-specific)

        sufficient_balance = employee.leave_balances.find_by(leave_type: 'CP')&.balance.to_f >= 15
        short_request = leave_request.days_count <= 2
        no_conflicts = !leave_request.conflicts_with_team?

        sufficient_balance && short_request && no_conflicts
      end

      # Calculate CP expiration date for current year
      def cp_expiration_date(year = Date.current.year)
        Date.new(year, CP_EXPIRY_MONTH, CP_EXPIRY_DAY)
      end

      # Accrue CP for a given month (called by background job)
      def accrue_monthly_cp!
        cp_balance = employee.leave_balances.find_or_create_by(leave_type: 'CP') do |balance|
          balance.balance = 0
          balance.accrued_this_year = 0
          balance.used_this_year = 0
        end

        accrual_amount = monthly_cp_accrual
        next_expiry = cp_expiration_date(Date.current.year + 1)

        cp_balance.update!(
          balance: cp_balance.balance + accrual_amount,
          accrued_this_year: cp_balance.accrued_this_year + accrual_amount,
          expires_at: next_expiry
        )

        accrual_amount
      end

      # Accrue RTT based on worked time (called weekly/monthly)
      def accrue_rtt!(worked_hours, period_weeks: 1)
        return 0 unless organization.rtt_enabled?

        rtt_balance = employee.leave_balances.find_or_create_by(leave_type: 'RTT') do |balance|
          balance.balance = 0
          balance.accrued_this_year = 0
          balance.used_this_year = 0
        end

        accrual_amount = calculate_rtt_accrual(worked_hours, period_weeks: period_weeks)
        return 0 if accrual_amount.zero?

        rtt_balance.update!(
          balance: rtt_balance.balance + accrual_amount,
          accrued_this_year: rtt_balance.accrued_this_year + accrual_amount
        )

        accrual_amount
      end

      private

      def calculate_months_worked(start_date, end_date)
        ((end_date.year - start_date.year) * 12) + (end_date.month - start_date.month)
      end

      def sufficient_balance?(leave_request)
        balance = employee.leave_balances.find_by(leave_type: leave_request.leave_type)
        return false unless balance

        balance.balance >= leave_request.days_count
      end

      def meets_consecutive_requirement?(leave_request)
        # If requesting leave in summer period, must request at least 10 consecutive days
        leave_request.days_count >= MINIMUM_CONSECUTIVE_LEAVE_DAYS
      end

      def in_summer_period?(leave_request)
        summer_start = Date.new(leave_request.start_date.year, 5, 1)
        summer_end = Date.new(leave_request.start_date.year, 10, 31)

        leave_request.start_date.between?(summer_start, summer_end)
      end

      def requesting_expired_cp?(leave_request)
        balance = employee.leave_balances.find_by(leave_type: 'CP')
        return false unless balance&.expires_at

        balance.expired?
      end

      def weekend?(date)
        date.saturday? || date.sunday?
      end

      def french_holiday?(date)
        # French public holidays
        holidays = french_holidays_for_year(date.year)
        holidays.include?(date)
      end

      def french_holidays_for_year(year)
        [
          Date.new(year, 1, 1),   # Nouvel An
          easter_monday(year),     # Lundi de Pâques
          Date.new(year, 5, 1),   # Fête du Travail
          Date.new(year, 5, 8),   # Victoire 1945
          ascension_day(year),     # Ascension
          whit_monday(year),       # Lundi de Pentecôte
          Date.new(year, 7, 14),  # Fête Nationale
          Date.new(year, 8, 15),  # Assomption
          Date.new(year, 11, 1),  # Toussaint
          Date.new(year, 11, 11), # Armistice 1918
          Date.new(year, 12, 25)  # Noël
        ]
      end

      # Easter calculation (Computus algorithm)
      def easter_sunday(year)
        a = year % 19
        b = year / 100
        c = year % 100
        d = b / 4
        e = b % 4
        f = (b + 8) / 25
        g = (b - f + 1) / 3
        h = (19 * a + b - d - g + 15) % 30
        i = c / 4
        k = c % 4
        l = (32 + 2 * e + 2 * i - h - k) % 7
        m = (a + 11 * h + 22 * l) / 451
        month = (h + l - 7 * m + 114) / 31
        day = ((h + l - 7 * m + 114) % 31) + 1

        Date.new(year, month, day)
      end

      def easter_monday(year)
        easter_sunday(year) + 1.day
      end

      def ascension_day(year)
        easter_sunday(year) + 39.days
      end

      def whit_monday(year)
        easter_sunday(year) + 50.days
      end

      def part_time_employee?
        employee.work_schedule&.weekly_hours.to_f < LEGAL_WORK_WEEK_HOURS
      end

      def part_time_ratio
        return 1.0 unless employee.work_schedule

        employee.work_schedule.weekly_hours.to_f / LEGAL_WORK_WEEK_HOURS
      end

      def monthly_cp_accrual
        if part_time_employee?
          CP_ACQUISITION_RATE * part_time_ratio
        else
          CP_ACQUISITION_RATE
        end
      end
    end
  end
end
