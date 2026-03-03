# frozen_string_literal: true

class EmployeeOnboardingsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_employee_onboarding

  def show; end

  private

  def set_employee_onboarding
    @employee_onboarding = current_employee.organization.employee_onboardings.find(params[:id])
    authorize @employee_onboarding
  end
end
