# frozen_string_literal: true

module Manager
  class TeamMembersController < BaseController
    before_action :set_team_member, only: [:show, :edit, :update, :destroy]

    def index
      @team_members = current_organization.employees
                        .where(manager_id: current_employee.id)
                        .order(:first_name, :last_name)
    end

    def show; end

    def new
      @team_member = current_organization.employees.build(
        manager: current_employee,
        role: 'employee',
        contract_type: 'CDI'
      )
      authorize @team_member, policy_class: Manager::TeamMemberPolicy
    end

    def create
      @team_member = current_organization.employees.build(team_member_params.merge(
        manager: current_employee,
        role: 'employee'
      ))
      authorize @team_member, policy_class: Manager::TeamMemberPolicy

      # Generate a temporary password for the new member
      temp_password = SecureRandom.hex(12)
      @team_member.password = temp_password
      @team_member.password_confirmation = temp_password

      if @team_member.save
        redirect_to manager_team_schedules_path, notice: "#{@team_member.full_name} a été ajouté à votre équipe."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @team_member.update(team_member_update_params)
        redirect_to manager_team_schedules_path, notice: "#{@team_member.full_name} a été mis à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Block deletion if employee has active linked data
      if has_active_linked_data?(@team_member)
        redirect_to manager_team_schedules_path,
          alert: "Impossible de supprimer #{@team_member.full_name} : il/elle a des données actives liées (onboarding, congés en cours, ou pointages récents)."
        return
      end

      @team_member.destroy
      redirect_to manager_team_schedules_path, notice: "#{@team_member.full_name} a été supprimé."
    end

    private

    def set_team_member
      @team_member = current_organization.employees
                       .where(manager_id: current_employee.id)
                       .find(params[:id])
      authorize @team_member, policy_class: Manager::TeamMemberPolicy
    end

    def has_active_linked_data?(member)
      active_onboardings = member.employee_onboardings.where(status: 'active').exists?
      active_leave_requests = member.leave_requests.where(status: %w[pending approved auto_approved]).exists?
      recent_time_entries = member.time_entries.where('clock_in >= ?', 30.days.ago).exists?

      active_onboardings || active_leave_requests || recent_time_entries
    end

    def team_member_params
      params.require(:employee).permit(
        :first_name, :last_name, :email,
        :job_title, :department,
        :contract_type, :start_date, :end_date
      )
    end

    def team_member_update_params
      params.require(:employee).permit(
        :first_name, :last_name, :email,
        :job_title, :department,
        :contract_type, :start_date, :end_date
      )
    end
  end
end
