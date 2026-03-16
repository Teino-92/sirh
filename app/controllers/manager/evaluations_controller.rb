module Manager
  class EvaluationsController < BaseController
    before_action :set_evaluation, only: [:show, :edit, :update, :destroy, :complete, :submit_manager_review]

    def index
      @evaluations = policy_scope(Evaluation)
                       .for_manager(current_employee)
                       .includes(:employee, :manager)
                       .order(period_end: :desc)

      if params[:status].present? && Evaluation.statuses.key?(params[:status])
        @evaluations = @evaluations.where(status: params[:status])
      end
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
        redirect_to manager_evaluations_path, notice: 'Évaluation créée'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @evaluation.update(evaluation_params)
        redirect_to manager_evaluation_path(@evaluation), notice: 'Évaluation mise à jour'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @evaluation.destroy
      redirect_to manager_evaluations_path, notice: 'Évaluation supprimée'
    end

    def launch
      @evaluation = current_organization.evaluations.find(params[:id])
      authorize @evaluation, :update?
      unless @evaluation.draft? || @evaluation.employee_review_pending?
        redirect_to manager_evaluation_path(@evaluation), alert: 'Cette évaluation ne peut pas être relancée'
        return
      end
      @evaluation.update!(status: :manager_review_pending)
      redirect_to manager_evaluation_path(@evaluation), notice: 'Évaluation lancée — vous pouvez maintenant noter le collaborateur'
    end

    def complete
      authorize @evaluation, :complete?
      final_score = params[:score].present? ? params[:score].to_i : nil
      @evaluation.complete!(final_score: final_score)
      redirect_to manager_evaluations_path, notice: 'Évaluation complétée'
    end

    def submit_manager_review
      authorize @evaluation, :submit_manager_review?
      @evaluation.transaction do
        criteria = params[:criteria_scores]&.values || []
        @evaluation.criteria_scores = criteria if criteria.any?
        @evaluation.update!(manager_review: params[:manager_review])
        @evaluation.complete!
      end
      RulesEngine.new(current_organization).trigger('evaluation.completed',
        resource: @evaluation,
        context: {
          'employee_role' => @evaluation.employee&.role.to_s,
          'period_year'   => @evaluation.period_end&.year.to_s
        })
      redirect_to manager_evaluation_path(@evaluation), notice: 'Évaluation complétée'
    rescue ActiveRecord::RecordInvalid
      render :show, status: :unprocessable_entity
    end

    private

    def set_evaluation
      @evaluation = current_organization.evaluations.find(params[:id])
      authorize @evaluation
    end

    def evaluation_params
      params.require(:evaluation).permit(:employee_id, :period_start, :period_end)
    end

  end
end
