# frozen_string_literal: true

module V1
  class LeaveRequestsController < BaseController
    # GET /api/v1/leave_requests
    def index
      scope = if params[:filter] == 'team' && current_employee.manager?
                LeaveRequest.for_team(current_employee)
              else
                current_employee.leave_requests
              end

      scope = scope.where(status: params[:status]) if params[:status].present?
      requests = scope.order(created_at: :desc).limit(50)

      render json: {
        requests: requests.map { |r| leave_request_json(r) }
      }
    end

    # POST /api/v1/leave_requests
    def create
      # Calculate working days
      policy_engine = LeaveManagement::Services::LeavePolicyEngine.new(current_employee)
      working_days = policy_engine.calculate_working_days(
        leave_params[:start_date].to_date,
        leave_params[:end_date].to_date
      )

      leave_request = current_employee.leave_requests.build(
        leave_type: leave_params[:leave_type],
        start_date: leave_params[:start_date],
        end_date: leave_params[:end_date],
        days_count: working_days,
        reason: leave_params[:reason]
      )

      # Validate with French legal engine
      validation_errors = policy_engine.validate_leave_request(leave_request)

      if validation_errors.any?
        return render json: {
          error: 'Validation failed',
          details: validation_errors
        }, status: :unprocessable_entity
      end

      # Check if can auto-approve
      if policy_engine.can_auto_approve?(leave_request)
        leave_request.save!
        leave_request.auto_approve!

        return render json: {
          request: leave_request_json(leave_request),
          auto_approved: true,
          message: 'Demande de congé approuvée automatiquement'
        }, status: :created
      end

      # Otherwise, save as pending
      leave_request.save!

      render json: {
        request: leave_request_json(leave_request),
        auto_approved: false,
        message: 'Demande de congé créée. En attente d\'approbation.'
      }, status: :created
    end

    # PATCH /api/v1/leave_requests/:id/approve
    def approve
      authorize_manager!

      leave_request = find_team_leave_request
      leave_request.approve!(current_employee)

      render json: {
        request: leave_request_json(leave_request),
        message: 'Demande de congé approuvée'
      }
    end

    # PATCH /api/v1/leave_requests/:id/reject
    def reject
      authorize_manager!

      leave_request = find_team_leave_request
      leave_request.reject!(current_employee)

      render json: {
        request: leave_request_json(leave_request),
        message: 'Demande de congé refusée'
      }
    end

    # GET /api/v1/leave_requests/pending_approvals
    # Manager endpoint to see all pending requests from their team
    def pending_approvals
      authorize_manager!

      requests = LeaveRequest.for_team(current_employee)
                             .pending
                             .order(created_at: :asc)

      render json: {
        requests: requests.map { |r| leave_request_json(r, include_employee: true) },
        count: requests.count
      }
    end

    # GET /api/v1/leave_requests/team_calendar
    # Manager endpoint to see team calendar
    def team_calendar
      authorize_manager!

      start_date = params[:start_date]&.to_date || Date.current
      end_date = params[:end_date]&.to_date || 1.month.from_now.to_date

      requests = LeaveRequest.for_team(current_employee)
                             .approved
                             .for_date_range(start_date, end_date)

      render json: {
        requests: requests.map { |r| leave_request_json(r, include_employee: true) },
        coverage_analysis: analyze_team_coverage(requests, start_date, end_date)
      }
    end

    private

    def leave_params
      params.require(:leave_request).permit(:leave_type, :start_date, :end_date, :reason)
    end

    def find_team_leave_request
      leave_request = LeaveRequest.find(params[:id])

      # Ensure request is from team member
      unless current_employee.team_members.include?(leave_request.employee)
        raise ActiveRecord::RecordNotFound, 'Leave request not found'
      end

      leave_request
    end

    def leave_request_json(request, include_employee: false)
      data = {
        id: request.id,
        leave_type: request.leave_type,
        leave_type_name: LeaveBalance.leave_type_name(request.leave_type),
        start_date: request.start_date,
        end_date: request.end_date,
        days_count: request.days_count,
        status: request.status,
        reason: request.reason,
        approved_at: request.approved_at,
        created_at: request.created_at
      }

      if include_employee
        data[:employee] = {
          id: request.employee.id,
          full_name: request.employee.full_name,
          department: request.employee.department
        }
      end

      if request.approved_by
        data[:approved_by] = {
          id: request.approved_by.id,
          full_name: request.approved_by.full_name
        }
      end

      data
    end

    def analyze_team_coverage(requests, start_date, end_date)
      # Analyze each day for coverage
      coverage = {}
      current_date = start_date

      while current_date <= end_date
        on_leave = requests.select { |r| r.start_date <= current_date && r.end_date >= current_date }
        team_size = current_employee.team_members.count

        coverage[current_date.to_s] = {
          on_leave_count: on_leave.count,
          team_size: team_size,
          coverage_percentage: ((team_size - on_leave.count).to_f / team_size * 100).round(1),
          critical: on_leave.count >= (team_size * 0.5) # 50%+ of team absent
        }

        current_date += 1.day
      end

      coverage
    end
  end
end
