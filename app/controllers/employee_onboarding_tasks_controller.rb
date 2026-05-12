# frozen_string_literal: true

class EmployeeOnboardingTasksController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_onboarding
  before_action :set_task

  def mark_done
    authorize @task, :mark_done?
    @task.mark_done!(current_employee)

    respond_to do |format|
      format.html { redirect_to employee_onboarding_path(@onboarding), notice: 'Tâche marquée comme faite.' }
      format.turbo_stream
    end
  rescue OnboardingTask::InvalidTransitionError => e
    respond_to do |format|
      format.html { redirect_to employee_onboarding_path(@onboarding), alert: e.message }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  private

  def set_onboarding
    @onboarding = current_organization.employee_onboardings.find(params[:employee_onboarding_id])
  end

  def set_task
    @task = @onboarding.onboarding_tasks.find(params[:id])
  end
end
