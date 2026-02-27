# frozen_string_literal: true

module Manager
  class OnboardingTasksController < ApplicationController
    before_action :authenticate_employee!

    def update
      @task = current_employee.organization.onboarding_tasks.find(params[:id])
      authorize @task

      @task.complete!(completed_by: current_employee)
      OnboardingScoreRefreshJob.perform_later(@task.onboarding_id)

      respond_to do |format|
        format.html { redirect_to manager_onboarding_path(@task.onboarding), notice: 'Tâche complétée.' }
        format.turbo_stream
      end
    end
  end
end
