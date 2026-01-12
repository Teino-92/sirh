# frozen_string_literal: true
  # Authorization handled by authorize_manager! before_action

module Manager
  class TeamSchedulesController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_manager!

    def index
      @team_members = policy_scope(Employee)
                                       .where(manager_id: current_employee.id)
                                       .includes(:weekly_schedule_plans, :work_schedule)
                                       .order(:first_name, :last_name)

      # Check which members have any weekly plans
      @members_with_schedule = @team_members.select { |m| m.weekly_schedule_plans.any? }
      @members_without_schedule = @team_members.select { |m| m.weekly_schedule_plans.empty? }
    end

    private

    def authorize_manager!
      unless current_employee.manager?
        redirect_to dashboard_path, alert: 'Accès réservé aux managers'
      end
    end
  end
end
