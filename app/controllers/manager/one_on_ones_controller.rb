module Manager
  class OneOnOnesController < ApplicationController
    before_action :authenticate_employee!
    before_action :set_one_on_one, only: [:show, :edit, :update, :destroy, :complete]

    def index
      @one_on_ones = policy_scope(OneOnOne)
                       .for_manager(current_employee)
                       .includes(:employee, :manager)
                       .order(scheduled_at: :desc)
    end

    def show; end
    def new
      @one_on_one = OneOnOne.new(manager: current_employee, organization: current_organization)
      authorize @one_on_one
    end

    def create
      @one_on_one = OneOnOne.new(one_on_one_params.merge(
        organization: current_organization,
        manager: current_employee
      ))
      authorize @one_on_one

      if @one_on_one.save
        redirect_to manager_one_on_ones_path, notice: '1:1 planifié'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end
    def update
      if @one_on_one.update(one_on_one_params)
        redirect_to manager_one_on_ones_path, notice: '1:1 mis à jour'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def complete
      authorize @one_on_one, :complete?
      @one_on_one.complete!(notes: params[:notes])
      redirect_to manager_one_on_ones_path, notice: '1:1 complété'
    end

    def destroy
      @one_on_one.destroy
      redirect_to manager_one_on_ones_path, notice: '1:1 supprimé'
    end

    private

    def set_one_on_one
      @one_on_one = OneOnOne.find(params[:id])
      authorize @one_on_one
    end

    def one_on_one_params
      params.require(:one_on_one).permit(:employee_id, :scheduled_at, :agenda, :notes)
    end

    def current_organization
      current_employee.organization
    end
  end
end
