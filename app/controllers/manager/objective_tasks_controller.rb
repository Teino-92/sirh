# frozen_string_literal: true

module Manager
  class ObjectiveTasksController < BaseController
    before_action :set_objective
    before_action :set_task, only: [:destroy, :validate_task]

    def create
      @task = @objective.objective_tasks.build(task_params)
      @task.organization = current_organization
      authorize @task

      if @task.save
        respond_to do |format|
          format.html { redirect_to manager_objective_path(@objective), notice: 'Tâche ajoutée.' }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { redirect_to manager_objective_path(@objective), alert: @task.errors.full_messages.first }
          format.turbo_stream { render turbo_stream: turbo_stream.replace("objective_task_form_#{@objective.id}", partial: 'manager/objective_tasks/form', locals: { objective: @objective, task: @task }) }
        end
      end
    end

    def destroy
      authorize @task
      @task.destroy
      respond_to do |format|
        format.html { redirect_to manager_objective_path(@objective), notice: 'Tâche supprimée.' }
        format.turbo_stream
      end
    end

    def validate_task
      authorize @task, :validate_task?
      @task.validate_task!(current_employee)
      respond_to do |format|
        format.html { redirect_to manager_objective_path(@objective), notice: 'Tâche validée.' }
        format.turbo_stream
      end
    rescue ObjectiveTask::InvalidTransitionError => e
      respond_to do |format|
        format.html { redirect_to manager_objective_path(@objective), alert: e.message }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: 'shared/flash', locals: { alert: e.message }) }
      end
    end

    private

    def set_objective
      @objective = current_organization.objectives.find(params[:objective_id])
    end

    def set_task
      @task = @objective.objective_tasks.find(params[:id])
    end

    def task_params
      params.require(:objective_task).permit(:title, :description, :deadline, :assigned_to_id, :position)
    end
  end
end
