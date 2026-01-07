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
    @my_pending_requests = @employee.leave_requests.pending
    @upcoming_leaves = @employee.leave_requests.approved
                               .where('start_date >= ?', Date.current)
                               .order(start_date: :asc)
                               .limit(3)

    # Weekly summary
    @weekly_hours = calculate_weekly_hours
    @expected_hours = @schedule&.weekly_hours || 35
  end

  private

  def calculate_weekly_hours
    entries = @employee.time_entries.this_week.completed
    entries.sum('duration_minutes') / 60.0
  end
end
