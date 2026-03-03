# frozen_string_literal: true

module Manager
  class EmployeeOnboardingTasksController < BaseController

    def update
      @task = current_organization.onboarding_tasks.find(params[:id])
      authorize @task

      @task.complete!(completed_by: current_employee)
      EmployeeOnboardingScoreRefreshJob.perform_later(@task.employee_onboarding_id)

      respond_to do |format|
        format.html { redirect_to manager_employee_onboarding_path(@task.employee_onboarding), notice: 'Tâche complétée.' }
        format.turbo_stream
      end
    end
  end
end
