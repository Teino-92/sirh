class EvaluationsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_evaluation, only: [:show, :submit_self_review]

  def index
    @evaluations = policy_scope(Evaluation)
                     .for_employee(current_employee)
                     .includes(:manager)
                     .order(period_end: :desc)
  end

  def show; end

  def submit_self_review
    authorize @evaluation, :submit_self_review?
    @evaluation.advance_to_manager_review!(self_review_text: params[:self_review])
    redirect_to evaluation_path(@evaluation), notice: 'Auto-évaluation soumise'
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private

  def set_evaluation
    @evaluation = current_employee.organization.evaluations.find(params[:id])
    authorize @evaluation
  end
end
