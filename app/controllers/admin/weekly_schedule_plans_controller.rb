# frozen_string_literal: true

module Admin
  class WeeklySchedulePlansController < BaseController
    def index
      @week_start = parse_week_param || Date.current.beginning_of_week(:monday)
      @week_end   = @week_start + 6.days
      @prev_week  = @week_start - 1.week
      @next_week  = @week_start + 1.week

      @employees         = policy_scope(Employee).order(:last_name, :first_name)
      plans              = policy_scope(WeeklySchedulePlan)
                             .where(week_start_date: @week_start)
                             .includes(:employee)
      @plans_by_employee = plans.index_by(&:employee_id)
    end

    private

    def parse_week_param
      params[:week]&.to_date&.beginning_of_week(:monday)
    rescue ArgumentError
      nil
    end
  end
end
