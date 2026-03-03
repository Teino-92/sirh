# frozen_string_literal: true
  # Authorization handled by authorize_manager! before_action

module Manager
  class TeamSchedulesController < BaseController

    def index
      @team_members = policy_scope(Employee)
                        .where(manager_id: current_employee.id)
                        .includes(:weekly_schedule_plans, :work_schedule)
                        .order(:first_name, :last_name)

      # Schedule data (for the planning section)
      @members_with_schedule = @team_members.select { |m| m.weekly_schedule_plans.any? }
      @members_without_schedule = @team_members.select { |m| m.weekly_schedule_plans.empty? }

      # Next 1:1s across the whole team (next 7 days)
      @upcoming_one_on_ones = current_organization.one_on_ones
                                .where(manager: current_employee)
                                .scheduled
                                .where(scheduled_at: Time.current..7.days.from_now)
                                .includes(:employee)
                                .order(:scheduled_at)

      # Per-member performance data (keyed by employee id)
      member_ids = @team_members.map(&:id)
      @member_objectives = current_organization.objectives
                                    .for_manager(current_employee)
                                    .where(owner_id: member_ids)
                                    .active
                                    .group_by(&:owner_id)
      @member_one_on_ones = current_organization.one_on_ones
                                    .where(manager: current_employee, employee_id: member_ids)
                                    .scheduled
                                    .where(scheduled_at: Time.current..)
                                    .order(:scheduled_at)
                                    .group_by(&:employee_id)
      @member_trainings = current_organization.training_assignments
                                            .where(employee_id: member_ids)
                                            .active
                                            .group_by(&:employee_id)
    end

    private

  end
end
