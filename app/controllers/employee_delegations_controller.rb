# frozen_string_literal: true

class EmployeeDelegationsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_delegation, only: [:destroy]

  def index
    authorize EmployeeDelegation
    @as_delegator = policy_scope(EmployeeDelegation)
                      .where(delegator: current_employee)
                      .order(starts_at: :desc)
                      .includes(:delegatee)
    @as_delegatee = policy_scope(EmployeeDelegation)
                      .active_now
                      .where(delegatee: current_employee)
                      .includes(:delegator)
  end

  def new
    @delegation = EmployeeDelegation.new(delegator: current_employee, starts_at: Date.current, ends_at: Date.current + 7.days)
    authorize @delegation
    load_colleagues
  end

  def create
    @delegation = EmployeeDelegation.new(delegation_params)
    @delegation.delegator     = current_employee
    @delegation.organization  = current_employee.organization
    @delegation.active        = true
    authorize @delegation

    if @delegation.save
      redirect_to employee_delegations_path, notice: "Délégation créée avec succès."
    else
      load_colleagues
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @delegation
    @delegation.update!(active: false)
    redirect_to employee_delegations_path, notice: "Délégation révoquée."
  end

  private

  def set_delegation
    @delegation = policy_scope(EmployeeDelegation).find(params[:id])
  end

  def load_colleagues
    @colleagues = current_employee.organization.employees
                    .where.not(id: current_employee.id)
                    .order(:last_name, :first_name)
  end

  def delegation_params
    params.require(:employee_delegation).permit(:delegatee_id, :role, :starts_at, :ends_at, :reason)
  end
end
