module Manager
  class EvaluationsController < ApplicationController
    before_action :authenticate_employee!
    before_action :set_evaluation, only: [:show, :edit, :update, :destroy, :complete, :submit_manager_review]

    def index
      @evaluations = policy_scope(Evaluation)
                       .for_manager(current_employee)
                       .includes(:employee, :manager)
                       .order(period_end: :desc)

      @evaluations = @evaluations.where(status: params[:status]) if params[:status].present?
    end

    def show; end

    def new
      @evaluation = Evaluation.new(manager: current_employee, organization: current_organization)
      authorize @evaluation
    end

    def create
      @evaluation = Evaluation.new(evaluation_params.merge(
        organization: current_organization,
        manager: current_employee,
        created_by: current_employee
      ))
      authorize @evaluation

      if @evaluation.save
        redirect_to manager_evaluations_path, notice: 'Evaluation created'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @evaluation.update(evaluation_params)
        redirect_to manager_evaluation_path(@evaluation), notice: 'Evaluation updated'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @evaluation.destroy
      redirect_to manager_evaluations_path, notice: 'Evaluation deleted'
    end

    def complete
      authorize @evaluation, :complete?
      @evaluation.complete!(final_score: params[:score]&.to_i)
      redirect_to manager_evaluations_path, notice: 'Evaluation completed'
    end

    def submit_manager_review
      authorize @evaluation, :submit_manager_review?
      if @evaluation.update(manager_review: params[:manager_review], status: :completed)
        redirect_to manager_evaluation_path(@evaluation), notice: 'Manager review submitted'
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_evaluation
      @evaluation = Evaluation.find(params[:id])
      authorize @evaluation
    end

    def evaluation_params
      params.require(:evaluation).permit(:employee_id, :period_start, :period_end, :self_review, :manager_review, :status)
    end

    def current_organization
      current_employee.organization
    end
  end
end
