# frozen_string_literal: true

module Manager
  class EmployeeOnboardingTasksController < BaseController

    def update
      @task = current_organization.onboarding_tasks.includes(:employee_onboarding).find(params[:id])
      authorize @task

      onboarding = @task.employee_onboarding
      raise ActiveRecord::RecordNotFound, "Onboarding introuvable pour cette tâche" if onboarding.nil?

      @task.complete!(completed_by: current_employee)
      EmployeeOnboardingScoreRefreshJob.perform_later(onboarding.id)
      fire_rules_engine('onboarding.task_completed', @task, {
        'task_type'        => @task.task_type.to_s,
        'assigned_to_role' => @task.assigned_to_role.to_s,
        'onboarding_day'   => onboarding.day_number.to_i
      })

      respond_to do |format|
        format.html { redirect_to manager_employee_onboarding_path(onboarding), notice: 'Tâche complétée.' }
        format.turbo_stream
      end
    end
  end
end
