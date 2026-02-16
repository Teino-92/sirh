# frozen_string_literal: true

class LeaveRequestsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_leave_request, only: [:approve, :reject, :reject_form, :cancel]
  before_action :authorize_manager!, only: [:approve, :reject, :reject_form, :pending_approvals, :team_calendar]

  def index
    @employee = current_employee
    @leave_balances = @employee.leave_balances

    # Filter by period - only show current employee's requests
    case params[:filter]
    when 'upcoming'
      @leave_requests = policy_scope(LeaveRequest).approved.where('start_date >= ?', Date.current).order(:start_date).includes(:employee, :approved_by)
    when 'history'
      @leave_requests = policy_scope(LeaveRequest).where('end_date < ?', Date.current).order(start_date: :desc).includes(:employee, :approved_by)
    else
      @leave_requests = policy_scope(LeaveRequest).order(created_at: :desc).includes(:employee, :approved_by)
    end
  end

  def new
    @leave_request = current_employee.leave_requests.build
    authorize @leave_request
    @leave_balances = current_employee.leave_balances
  end

  def create
    start_date = leave_request_params[:start_date].to_date
    end_date = leave_request_params[:end_date].to_date

    # Initialize LeavePolicyEngine for the employee
    policy_engine = LeaveManagement::Services::LeavePolicyEngine.new(current_employee)

    # Calculate working days with French legal compliance
    working_days = policy_engine.calculate_working_days(start_date, end_date)

    # Build the leave request (don't save yet, we need to validate first)
    @leave_request = current_employee.leave_requests.build(
      leave_type: leave_request_params[:leave_type],
      start_date: start_date,
      end_date: end_date,
      start_half_day: leave_request_params[:start_half_day],
      end_half_day: leave_request_params[:end_half_day],
      days_count: working_days,
      reason: leave_request_params[:reason]
    )

    # Validate the request using LeavePolicyEngine
    validation_errors = policy_engine.validate_leave_request(@leave_request)

    unless validation_errors.empty?
      @leave_balances = current_employee.leave_balances
      flash.now[:alert] = validation_errors.join(', ')
      render :new, status: :unprocessable_entity
      return
    end

    authorize @leave_request

    if @leave_request.save
      # Envoyer notification email de manière asynchrone
      LeaveRequestNotificationJob.perform_later(:submitted, @leave_request.id)

      # Check auto-approval via LeavePolicyEngine
      if policy_engine.can_auto_approve?(@leave_request)
        @leave_request.auto_approve!
        redirect_to leave_requests_path, notice: 'Demande de congé approuvée automatiquement ✓'
      else
        redirect_to leave_requests_path, notice: 'Demande de congé créée. En attente d\'approbation.'
      end
    else
      @leave_balances = current_employee.leave_balances
      render :new, status: :unprocessable_entity
    end
  end

  def pending_approvals
    @pending_requests = policy_scope(LeaveRequest)
                        .joins(:employee)
                        .where(employees: { manager_id: current_employee.id })
                        .pending
                        .order('leave_requests.created_at ASC')
                        .includes(:employee, :approved_by)

    # Stats for dashboard
    @approved_this_month = LeaveRequest
                           .joins(:employee)
                           .where(employees: { manager_id: current_employee.id })
                           .approved
                           .where('leave_requests.created_at >= ?', Date.current.beginning_of_month)
                           .count

    # Team absences for conflict detection (simplified)
    @team_absences_by_date = {}
  end

  def approve
    authorize @leave_request
    @leave_request.approve!(current_employee)

    # Envoyer notification email de manière asynchrone
    LeaveRequestNotificationJob.perform_later(:approved, @leave_request.id)

    redirect_to pending_approvals_leave_requests_path, notice: 'Demande approuvée'
  end

  def reject_form
    authorize @leave_request
    # Render the rejection form modal/page
  end

  def reject
    authorize @leave_request
    @leave_request.reject!(current_employee, reason: params[:rejection_reason])

    # Envoyer notification email de manière asynchrone
    LeaveRequestNotificationJob.perform_later(:rejected, @leave_request.id)

    redirect_to pending_approvals_leave_requests_path, notice: 'Demande refusée'
  end

  def cancel
    authorize @leave_request

    unless @leave_request.pending?
      redirect_to leave_requests_path, alert: 'Seules les demandes en attente peuvent être annulées'
      return
    end

    @leave_request.update!(status: 'cancelled')

    # Envoyer notification email de manière asynchrone
    LeaveRequestNotificationJob.perform_later(:cancelled, @leave_request.id)

    redirect_to leave_requests_path, notice: 'Demande annulée avec succès'
  end

  def team_calendar
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month

    @team_members = current_employee.team_members
    @team_leave_requests = policy_scope(LeaveRequest)
                           .joins(:employee)
                           .where(employees: { manager_id: current_employee.id })
                           .approved
                           .for_date_range(@start_date, @end_date)
                           .includes(:employee)
  end

  private

  def set_leave_request
    @leave_request = LeaveRequest.find(params[:id])
  end

  def leave_request_params
    params.require(:leave_request).permit(:leave_type, :start_date, :end_date, :start_half_day, :end_half_day, :reason)
  end

  def authorize_manager!
    unless current_employee.manager?
      redirect_to dashboard_path, alert: 'Accès réservé aux managers'
    end
  end
end
