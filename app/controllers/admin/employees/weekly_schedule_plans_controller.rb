# frozen_string_literal: true

module Admin
  module Employees
    class WeeklySchedulePlansController < Admin::BaseController
      before_action :set_employee

      def index
        @current_date   = parse_date_param || Date.current
        @start_date     = @current_date.beginning_of_month.beginning_of_week(:monday)
        @end_date       = @current_date.end_of_month.end_of_week(:sunday)

        @weekly_plans   = policy_scope(WeeklySchedulePlan)
                            .where(employee: @employee)
                            .where(week_start_date: @start_date..@end_date)
                            .index_by(&:week_start_date)

        @calendar_weeks = (@start_date..@end_date).step(7).map { |d| d }
      end

      private

      def set_employee
        @employee = Employee.find(params[:employee_id])
        authorize @employee, :show?
      end

      def parse_date_param
        params[:date]&.to_date
      rescue ArgumentError
        nil
      end
    end
  end
end
