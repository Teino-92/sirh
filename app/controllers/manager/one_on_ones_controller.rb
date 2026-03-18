module Manager
  class OneOnOnesController < BaseController
    before_action :set_one_on_one, only: [:show, :edit, :update, :destroy, :complete]

    def index
      base = policy_scope(OneOnOne)
               .for_manager(current_employee)
               .includes(:employee)

      @tab = params[:tab].presence_in(%w[upcoming past]) || 'upcoming'

      if @tab == 'past'
        @one_on_ones = base.where('scheduled_at < ?', Time.current).order(scheduled_at: :desc)
      else
        @one_on_ones = base.where('scheduled_at >= ?', Time.current).order(scheduled_at: :asc)
      end
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
        fire_rules_engine('one_on_one.scheduled', @one_on_one, rules_context_for(@one_on_one))
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
      fire_rules_engine('one_on_one.completed', @one_on_one, rules_context_for(@one_on_one))
      redirect_to manager_one_on_ones_path, notice: '1:1 complété'
    end

    def destroy
      @one_on_one.destroy
      redirect_to manager_one_on_ones_path, notice: '1:1 supprimé'
    end

    private

    def set_one_on_one
      @one_on_one = current_organization.one_on_ones.find(params[:id])
      authorize @one_on_one
    end

    def one_on_one_params
      params.require(:one_on_one).permit(:employee_id, :scheduled_at, :agenda, :notes)
    end

    def rules_context_for(one_on_one)
      {
        'employee_role' => one_on_one.employee&.role.to_s,
        'days_until'    => one_on_one.scheduled_at ? (one_on_one.scheduled_at.to_date - Date.current).to_i : 0,
        'agenda_present'=> one_on_one.agenda.present?
      }
    end

  end
end
