# frozen_string_literal: true

module Manager
  class EmployeeOnboardingsController < BaseController
    before_action :set_employee_onboarding, only: [:show, :edit, :update]

    def index
      @employee_onboardings = policy_scope(EmployeeOnboarding)
                                .for_manager(current_employee)
                                .includes(:employee, :onboarding_template, :onboarding_tasks)
                                .order(start_date: :desc)
    end

    def show
      @tasks_by_role = @employee_onboarding.onboarding_tasks
                                           .order(:due_date)
                                           .group_by(&:assigned_to_role)
    end

    def new
      @employee_onboarding = EmployeeOnboarding.new(manager: current_employee,
                                                    organization: current_organization)
      @templates    = policy_scope(OnboardingTemplate)
      @team_members = current_employee.team_members.order(:last_name, :first_name)
      authorize @employee_onboarding
    end

    def create
      @employee_onboarding = EmployeeOnboarding.new(employee_onboarding_params.merge(
        organization: current_organization,
        manager:      current_employee
      ))
      authorize @employee_onboarding

      if @employee_onboarding.save
        EmployeeOnboardingInitializerService.new(@employee_onboarding).call
        fire_rules_engine('onboarding.started', @employee_onboarding, {
          'employee_role' => @employee_onboarding.employee&.role.to_s,
          'duration_days' => @employee_onboarding.end_date && @employee_onboarding.start_date ? (@employee_onboarding.end_date - @employee_onboarding.start_date).to_i : nil
        }.compact)
        redirect_to manager_employee_onboarding_path(@employee_onboarding),
                    notice: "Onboarding démarré pour #{@employee_onboarding.employee.full_name}."
      else
        @templates    = policy_scope(OnboardingTemplate)
        @team_members = current_employee.team_members.order(:last_name, :first_name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @templates      = policy_scope(OnboardingTemplate)
      @team_members   = current_employee.team_members.order(:last_name, :first_name)
    end

    def update
      if @employee_onboarding.update(employee_onboarding_params)
        redirect_to manager_employee_onboarding_path(@employee_onboarding),
                    notice: 'Onboarding mis à jour.'
      else
        @templates = policy_scope(OnboardingTemplate)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_employee_onboarding
      @employee_onboarding = current_organization.employee_onboardings.find(params[:id])
      authorize @employee_onboarding
    end

    def employee_onboarding_params
      params.require(:employee_onboarding).permit(:employee_id, :onboarding_template_id,
                                                  :start_date, :end_date, :notes)
    end
  end
end
