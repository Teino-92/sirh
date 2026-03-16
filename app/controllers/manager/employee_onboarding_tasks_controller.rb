# frozen_string_literal: true

module Manager
  class EmployeeOnboardingTasksController < BaseController

    def update
      @task = current_organization.onboarding_tasks.find(params[:id])
      authorize @task

      @task.complete!(completed_by: current_employee)
      EmployeeOnboardingScoreRefreshJob.perform_later(@task.employee_onboarding_id)
      RulesEngine.new(current_organization).trigger('onboarding.task_completed',
        resource: @task,
        context: {
          'task_type'        => @task.task_type.to_s,
          'assigned_to_role' => @task.assigned_to_role.to_s,
          'onboarding_day'   => @task.employee_onboarding&.day_number.to_i
        })

      respond_to do |format|
        format.html { redirect_to manager_employee_onboarding_path(@task.employee_onboarding), notice: 'Tâche complétée.' }
        format.turbo_stream
      end
    end
  end
end
