class TrainingAssignmentsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_assignment, only: [:show, :complete]

  def index
    @assignments = policy_scope(TrainingAssignment)
                     .includes(:training, :assigned_by)
                     .order(assigned_at: :desc)

    if params[:status].present? && TrainingAssignment.statuses.key?(params[:status])
      @assignments = @assignments.where(status: params[:status])
    end
  end

  def show; end

  def complete
    authorize @assignment, :complete?
    @assignment.complete!(notes: params[:completion_notes])
    redirect_to training_assignment_path(@assignment), notice: 'Training marked as complete'
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private

  def set_assignment
    @assignment = TrainingAssignment.find(params[:id])
    authorize @assignment
  end
end
