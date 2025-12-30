# frozen_string_literal: true

class LeaveRequestsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_leave_request, only: [:approve, :reject, :cancel]
  before_action :authorize_manager!, only: [:approve, :reject, :pending_approvals, :team_calendar]

  def index
    @employee = current_employee
    @leave_balances = @employee.leave_balances

    # Filter by period
    case params[:filter]
    when 'upcoming'
      @leave_requests = @employee.leave_requests.approved.where('start_date >= ?', Date.current).order(:start_date)
    when 'history'
      @leave_requests = @employee.leave_requests.where('end_date < ?', Date.current).order(start_date: :desc)
    else
      @leave_requests = @employee.leave_requests.order(created_at: :desc)
    end
  end

  def new
    @leave_request = current_employee.leave_requests.build
    @leave_balances = current_employee.leave_balances
  end

  def create
    start_date = leave_request_params[:start_date].to_date
    end_date = leave_request_params[:end_date].to_date

    # Calculate working days (simplified - you'd use the legal engine in production)
    working_days = calculate_working_days(start_date, end_date,
                                          leave_request_params[:start_half_day],
                                          leave_request_params[:end_half_day])

    @leave_request = current_employee.leave_requests.build(
      leave_type: leave_request_params[:leave_type],
      start_date: start_date,
      end_date: end_date,
      start_half_day: leave_request_params[:start_half_day],
      end_half_day: leave_request_params[:end_half_day],
      days_count: working_days,
      reason: leave_request_params[:reason]
    )

    # TODO: Use LeavePolicyEngine for validation and auto-approve logic

    if @leave_request.save
      # Simple auto-approve logic for now
      if can_auto_approve?(@leave_request)
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
    @pending_requests = LeaveRequest
                        .joins(:employee)
                        .where(employees: { manager_id: current_employee.id })
                        .pending
                        .order('leave_requests.created_at ASC')
                        .includes(:employee)

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
    @leave_request.approve!(current_employee)
    redirect_to pending_approvals_leave_requests_path, notice: 'Demande approuvée'
  end

  def reject
    @leave_request.reject!(current_employee)
    redirect_to pending_approvals_leave_requests_path, notice: 'Demande refusée'
  end

  def cancel
    unless @leave_request.employee_id == current_employee.id
      redirect_to leave_requests_path, alert: 'Vous ne pouvez annuler que vos propres demandes'
      return
    end

    unless @leave_request.pending?
      redirect_to leave_requests_path, alert: 'Seules les demandes en attente peuvent être annulées'
      return
    end

    @leave_request.update!(status: 'cancelled')
    redirect_to leave_requests_path, notice: 'Demande annulée avec succès'
  end

  def team_calendar
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month

    @team_leave_requests = LeaveRequest
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

  def calculate_working_days(start_date, end_date, start_half_day = nil, end_half_day = nil)
    days = 0.0
    current_date = start_date

    while current_date <= end_date
      unless current_date.saturday? || current_date.sunday?
        if current_date == start_date && start_half_day.present?
          days += 0.5
        elsif current_date == end_date && end_half_day.present?
          days += 0.5
        else
          days += 1
        end
      end
      current_date += 1.day
    end

    days
  end

  def can_auto_approve?(request)
    return false unless request.leave_type == 'CP'

    balance = current_employee.leave_balances.find_by(leave_type: 'CP')
    return false unless balance

    # Auto-approve if: 1-2 days, sufficient balance (15+ days), no team conflicts
    request.days_count <= 2 && balance.balance >= 15
  end
end
