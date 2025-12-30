# frozen_string_literal: true

module TimeTracking
  module Services
    class RttAccrualService
      attr_reader :employee

      def initialize(employee)
        @employee = employee
      end

      def calculate_and_accrue_weekly
        return unless employee.organization.rtt_enabled?

        # Calculate hours worked this week
        week_start = Date.current.beginning_of_week
        week_end = Date.current.end_of_week

        total_hours = employee.time_entries
                              .completed
                              .for_date_range(week_start, week_end)
                              .sum('duration_minutes') / 60.0

        # Use the legal compliance engine
        policy_engine = LeaveManagement::Services::LeavePolicyEngine.new(employee)
        policy_engine.accrue_rtt!(total_hours, period_weeks: 1)
      end

      def calculate_and_accrue_monthly
        return unless employee.organization.rtt_enabled?

        # Calculate hours worked this month
        month_start = Date.current.beginning_of_month
        month_end = Date.current.end_of_month

        total_hours = employee.time_entries
                              .completed
                              .for_date_range(month_start, month_end)
                              .sum('duration_minutes') / 60.0

        weeks_in_month = ((month_end - month_start) / 7.0).ceil

        # Use the legal compliance engine
        policy_engine = LeaveManagement::Services::LeavePolicyEngine.new(employee)
        policy_engine.accrue_rtt!(total_hours, period_weeks: weeks_in_month)
      end
    end
  end
end
