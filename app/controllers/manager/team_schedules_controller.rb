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

    def planning
      @current_month = params[:month]&.to_date&.beginning_of_month || Date.current.beginning_of_month
      @prev_month = @current_month - 1.month
      @next_month = @current_month + 1.month

      @team_members = policy_scope(Employee)
                        .where(manager_id: current_employee.id)
                        .order(:first_name, :last_name)

      # Build the 4-5 weeks covering this month
      @weeks = []
      week = @current_month.beginning_of_week(:monday)
      last_week = @current_month.end_of_month.beginning_of_week(:monday)
      while week <= last_week
        @weeks << week
        week += 1.week
      end

      # Load all plans for these weeks, keyed by [employee_id, week_start]
      week_range = @weeks.first..@weeks.last + 6.days
      plans = policy_scope(WeeklySchedulePlan)
                .where(employee: @team_members)
                .where(week_start_date: week_range)
      @plans_by_key = plans.index_by { |p| [p.employee_id, p.week_start_date] }

      @schedule_templates = load_schedule_templates
    end

    private

    def load_schedule_templates
      {
        'full_time_35h' => { name: 'Temps plein 35h', color: 'indigo',
          pattern: { 'monday' => '09:00-17:00', 'tuesday' => '09:00-17:00', 'wednesday' => '09:00-17:00',
                     'thursday' => '09:00-17:00', 'friday' => '09:00-17:00', 'saturday' => 'off', 'sunday' => 'off' } },
        'full_time_39h' => { name: 'Temps plein 39h', color: 'purple',
          pattern: { 'monday' => '09:00-18:00', 'tuesday' => '09:00-18:00', 'wednesday' => '09:00-18:00',
                     'thursday' => '09:00-18:00', 'friday' => '09:00-18:00', 'saturday' => 'off', 'sunday' => 'off' } },
        'part_time_24h' => { name: 'Temps partiel 24h', color: 'green',
          pattern: { 'monday' => '09:00-17:00', 'tuesday' => '09:00-17:00', 'wednesday' => '09:00-17:00',
                     'thursday' => 'off', 'friday' => 'off', 'saturday' => 'off', 'sunday' => 'off' } },
        'off' => { name: 'Repos / Congé', color: 'gray',
          pattern: { 'monday' => 'off', 'tuesday' => 'off', 'wednesday' => 'off',
                     'thursday' => 'off', 'friday' => 'off', 'saturday' => 'off', 'sunday' => 'off' } },
      }
    end

  end
end
