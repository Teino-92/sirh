# frozen_string_literal: true

module Api
  module V1
  # Mobile-first dashboard endpoint - single call for all dashboard data
  class DashboardController < BaseController
    # GET /api/v1/me/dashboard
    # Returns everything a user needs to see on app open
    def show
      employee = current_employee
      today = Date.current

      # Current time entry (if clocked in)
      current_shift = employee.time_entries.active.first

      # Today's schedule
      schedule = employee.work_schedule
      today_schedule = schedule&.schedule_pattern&.dig(today.strftime('%A').downcase)

      # Leave balances
      balances = employee.leave_balances.map { |b| serialize_leave_balance(b) }

      # Pending actions (if manager)
      pending_approvals = if employee.manager?
                            employee.team_members
                                    .joins(:leave_requests)
                                    .merge(LeaveRequest.pending)
                                    .count
                          else
                            0
                          end

      # Team status (if manager)
      team_status = if employee.manager?
                      build_team_status(employee)
                    else
                      nil
                    end

      # My pending requests
      my_pending_requests = employee.leave_requests.pending.count

      render json: {
        employee: {
          id: employee.id,
          full_name: employee.full_name,
          role: employee.role,
          department: employee.department
        },
        current_shift: current_shift ? serialize_time_entry(current_shift) : nil,
        today_schedule: today_schedule,
        leave_balances: balances,
        pending_approvals: pending_approvals,
        my_pending_requests: my_pending_requests,
        team_status: team_status,
        quick_actions: quick_actions(employee)
      }
    end

    private

    def build_team_status(manager)
      team = manager.team_members

      {
        total_members: team.count,
        working_now: team.joins(:time_entries).merge(TimeEntry.active).count,
        on_leave_today: team.joins(:leave_requests)
                            .merge(LeaveRequest.approved.for_date_range(Date.current, Date.current))
                            .count
      }
    end

    def quick_actions(employee)
      actions = []

      # Clock in/out action
      if employee.time_entries.active.any?
        actions << { type: 'clock_out', label: 'Pointer la sortie', icon: 'clock-out' }
      else
        actions << { type: 'clock_in', label: 'Pointer l\'entrée', icon: 'clock-in' }
      end

      # Request leave action
      actions << { type: 'request_leave', label: 'Demander un congé', icon: 'calendar' }

      # Manager-specific actions
      if employee.manager?
        actions << { type: 'team_calendar', label: 'Calendrier équipe', icon: 'users' }
        actions << { type: 'approve_requests', label: 'Approuver demandes', icon: 'check-circle' }
      end

      actions
    end
  end
  end
end
