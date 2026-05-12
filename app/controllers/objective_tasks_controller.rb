# frozen_string_literal: true

class ObjectiveTasksController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_objective
  before_action :set_task

  def complete
    authorize @task
    @task.complete!(current_employee)
    respond_to do |format|
      format.html { redirect_to objective_path(@objective), notice: 'Tâche marquée comme faite.' }
      format.turbo_stream
    end
  rescue ObjectiveTask::InvalidTransitionError => e
    respond_to do |format|
      format.html { redirect_to objective_path(@objective), alert: e.message }
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
end
