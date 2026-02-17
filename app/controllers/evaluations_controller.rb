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
    if @evaluation.update(self_review: params[:self_review], status: :manager_review_pending)
      redirect_to evaluation_path(@evaluation), notice: 'Self review submitted'
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_evaluation
    @evaluation = Evaluation.find(params[:id])
    authorize @evaluation
  end
end
