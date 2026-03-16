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
    begin
      RulesEngine.new(current_employee.organization).trigger('training_assignment.completed',
        resource: @assignment,
        context: {
          'training_type' => @assignment.training.training_type.to_s,
          'employee_role' => @assignment.employee.role.to_s
        })
    rescue => e
      Rails.logger.error("[RulesEngine] training_assignment.completed failed silently: #{e.message}")
    end
    redirect_to training_assignment_path(@assignment), notice: 'Formation marquée comme terminée'
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private

  def set_assignment
    @assignment = TrainingAssignment
      .joins(:employee)
      .where(employees: { organization_id: current_employee.organization_id })
      .find(params[:id])
    authorize @assignment
  end
end
