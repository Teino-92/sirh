# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_employee!

  def show
    # Dashboard accessible to all authenticated employees
    authorize :dashboard, :show?
    @employee = current_employee
    @today = Date.current

    # Current time entry (if clocked in)
    @current_shift = @employee.time_entries.active.first

    # Today's schedule
    @schedule = @employee.work_schedule
    @today_schedule = @schedule&.schedule_pattern&.dig(@today.strftime('%A').downcase)

    # Leave balances
    @leave_balances = @employee.leave_balances

    # Pending actions (if manager)
    @pending_approvals_count = if @employee.manager?
                                  @employee.team_members
                                           .joins(:leave_requests)
                                           .merge(LeaveRequest.pending)
                                           .count
                                else
                                  0
                                end

    # My pending requests
    @my_pending_requests = @employee.leave_requests.pending.includes(:approved_by)
    @upcoming_leaves = @employee.leave_requests.approved
                               .where('start_date >= ?', Date.current)
                               .order(start_date: :asc)
                               .limit(3)
                               .includes(:approved_by)

    # Weekly summary
    @weekly_hours = calculate_weekly_hours
    @expected_hours = @schedule&.weekly_hours || 35

    # Personal weekly plan
    week_start = @today.beginning_of_week(:monday)
    @weekly_plan = @employee.weekly_schedule_plans.find_by(week_start_date: week_start)
    @week_time_entries = @employee.time_entries.this_week.completed
                                  .group_by { |e| e.clock_in.to_date }

    # Manager: team weekly presence summary
    if @employee.manager?
      @team_this_week = load_team_week_summary(week_start)
    end

    # Trial period alerts (manager + HR/admin)
    @trial_period_alerts = load_trial_period_alerts if @employee.manager? || @employee.hr_or_admin?

    # Performance Layer
    load_performance_layer_data

    # HR/Admin: company-wide overview
    load_hr_overview_data if @employee.hr_or_admin?

    # Manager OS: team-scoped overview (active onboardings)
    load_manager_os_data if @employee.manager? && @employee.organization.manager_os?
  end

  private

  def load_team_week_summary(week_start)
    days = (0..6).map { |i| week_start + i.days }
    team = @employee.team_members.includes(:weekly_schedule_plans, :leave_requests)

    team.map do |member|
      plan = member.weekly_schedule_plans.find { |p| p.week_start_date == week_start }
      leaves_this_week = member.leave_requests
                               .where(status: %w[approved auto_approved])
                               .where('start_date <= ? AND end_date >= ?', week_start + 6.days, week_start)

      day_statuses = days.map do |day|
        day_name = day.strftime('%A').downcase
        on_leave = leaves_this_week.any? { |l| day >= l.start_date && day <= l.end_date }
        has_schedule = plan&.schedule_pattern&.dig(day_name).present? &&
                       plan.schedule_pattern[day_name] != 'off'

        if on_leave
          :leave
        elsif has_schedule
          :work
        else
          :off
        end
      end

      { employee: member, days: day_statuses }
    end
  end

  def calculate_weekly_hours
    entries = @employee.time_entries.this_week.completed
    entries.sum('duration_minutes') / 60.0
  end

  def load_performance_layer_data
    # Employee: my active objectives
    @my_active_objectives_count = @employee.owned_objectives.active.count

    # Employee: my next 1:1
    @my_next_one_on_one = @employee.employee_one_on_ones
                                    .scheduled
                                    .where('scheduled_at >= ?', Time.current)
                                    .order(scheduled_at: :asc)
                                    .first

    # Employee: my active training assignments
    @my_pending_training_count = @employee.training_assignments.active.count

    # Manager-only additions
    return unless @employee.manager?

    # Overdue objectives for team
    @team_overdue_objectives_count = Objective
      .for_manager(@employee)
      .overdue
      .count

    # Upcoming 1:1s (next 7 days)
    @upcoming_one_on_ones = OneOnOne
      .where(manager: @employee)
      .scheduled
      .where(scheduled_at: Time.current..7.days.from_now)
      .includes(:employee)
      .order(scheduled_at: :asc)
      .limit(3)

    # Pending manager reviews
    @pending_manager_reviews_count = Evaluation
      .for_manager(@employee)
      .where(status: :manager_review_pending)
      .count
  end

  def load_trial_period_alerts
    cutoff = Date.today + 14.days
    base = @employee.organization.employees
                    .where.not(trial_period_end: nil)
                    .where(trial_period_end: Date.today..cutoff)
                    .order(:trial_period_end)

    if @employee.hr_or_admin?
      base
    else
      base.where(manager_id: @employee.id)
    end
  end

  def load_manager_os_data
    @active_onboardings = EmployeeOnboarding
      .where(organization: @employee.organization)
      .where(manager_id: @employee.id)
      .active
      .includes(:employee, :onboarding_tasks)
      .order(:start_date)
  end

  def load_hr_overview_data
    today = Date.current
    org   = @employee.organization

    # Absences today (approved leave covering today)
    @absences_today = LeaveRequest
      .where(organization: org)
      .where(status: %w[approved auto_approved])
      .where('start_date <= ? AND end_date >= ?', today, today)
      .includes(:employee)
      .order(:leave_type)

    # Active onboardings with progress
    @active_onboardings = EmployeeOnboarding
      .where(organization: org)
      .active
      .includes(:employee, :manager, :onboarding_tasks)
      .order(:start_date)
  end
end
