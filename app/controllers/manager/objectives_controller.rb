module Manager
  class ObjectivesController < BaseController
    before_action :set_objective, only: [:show, :edit, :update, :destroy, :complete]

    def index
      @objectives = policy_scope(Objective)
                      .for_manager(current_employee)
                      .includes(:owner)
                      .order(deadline: :asc)

      if params[:status].present? && Objective.statuses.key?(params[:status])
        @objectives = @objectives.where(status: params[:status])
      end
    end

    def show; end
    def new
      @objective = Objective.new(manager: current_employee, organization: current_organization)
      authorize @objective
    end

    def create
      @objective = Objective.new(objective_params.merge(
        organization: current_organization,
        manager: current_employee,
        created_by: current_employee,
        owner_type: 'Employee'
      ))
      authorize @objective

      if @objective.save
        fire_rules_engine('objective.assigned', @objective, rules_context_for(@objective))
        redirect_to manager_objectives_path, notice: 'Objectif créé'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end
    def update
      if @objective.update(objective_params)
        redirect_to manager_objectives_path, notice: 'Objectif mis à jour'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def complete
      authorize @objective, :complete?
      @objective.complete!
      fire_rules_engine('objective.completed', @objective, rules_context_for(@objective))
      redirect_to manager_objectives_path, notice: 'Objectif marqué comme complété'
    rescue ActiveRecord::RecordInvalid
      redirect_to manager_objective_path(@objective), alert: 'Impossible de compléter cet objectif.'
    end

    def destroy
      @objective.destroy
      redirect_to manager_objectives_path, notice: 'Objectif supprimé'
    end

    private

    def set_objective
      @objective = current_organization.objectives.find(params[:id])
      authorize @objective
    end

    def objective_params
      params.require(:objective).permit(:title, :description, :owner_id, :deadline, :priority)
    end

    def rules_context_for(objective)
      {
        'priority'      => objective.priority.to_s,
        'status'        => objective.status.to_s,
        'employee_role' => objective.owner&.role.to_s,
        'deadline_days' => objective.deadline ? (objective.deadline - Date.current).to_i : nil
      }.compact
    end

  end
end
