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

    # Performance Layer
    load_performance_layer_data
  end

  private

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
end
