module Manager
  class ObjectivesController < ApplicationController
    before_action :authenticate_employee!
    before_action :set_objective, only: [:show, :edit, :update, :destroy, :complete]

    def index
      @objectives = policy_scope(Objective)
                      .for_manager(current_employee)
                      .includes(:owner, :manager)
                      .order(deadline: :asc)

      @objectives = @objectives.where(status: params[:status]) if params[:status].present?
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
        created_by: current_employee
      ))
      authorize @objective

      if @objective.save
        redirect_to manager_objectives_path, notice: 'Objective created'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end
    def update
      if @objective.update(objective_params)
        redirect_to manager_objectives_path, notice: 'Objective updated'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def complete
      authorize @objective
      @objective.complete!
      redirect_to manager_objectives_path, notice: 'Objectif marqué comme complété'
    end

    def destroy
      @objective.destroy
      redirect_to manager_objectives_path, notice: 'Objective deleted'
    end

    private

    def set_objective
      @objective = Objective.find(params[:id])
      authorize @objective
    end

    def objective_params
      params.require(:objective).permit(:title, :description, :owner_id, :owner_type, :deadline, :priority)
    end

    def current_organization
      current_employee.organization
    end
  end
end
