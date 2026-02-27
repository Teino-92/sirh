# frozen_string_literal: true

module Manager
  class OnboardingsController < ApplicationController
    before_action :authenticate_employee!
    before_action :set_onboarding, only: [:show, :edit, :update]

    def index
      @onboardings = policy_scope(Onboarding)
                       .for_manager(current_employee)
                       .includes(:employee, :onboarding_template, :onboarding_tasks)
                       .order(start_date: :desc)
    end

    def show
      @tasks_by_role = @onboarding.onboarding_tasks
                                  .order(:due_date)
                                  .group_by(&:assigned_to_role)
    end

    def new
      @onboarding = Onboarding.new(manager: current_employee,
                                   organization: current_organization)
      @templates = policy_scope(OnboardingTemplate)
      authorize @onboarding
    end

    def create
      @onboarding = Onboarding.new(onboarding_params.merge(
        organization: current_organization,
        manager:      current_employee
      ))
      authorize @onboarding

      if @onboarding.save
        OnboardingInitializerService.new(@onboarding).call
        redirect_to manager_onboarding_path(@onboarding),
                    notice: "Onboarding démarré pour #{@onboarding.employee.full_name}."
      else
        @templates = policy_scope(OnboardingTemplate)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @templates = policy_scope(OnboardingTemplate)
    end

    def update
      if @onboarding.update(onboarding_params)
        redirect_to manager_onboarding_path(@onboarding),
                    notice: 'Onboarding mis à jour.'
      else
        @templates = policy_scope(OnboardingTemplate)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_onboarding
      @onboarding = current_organization.onboardings.find(params[:id])
      authorize @onboarding
    end

    def onboarding_params
      params.require(:onboarding).permit(:employee_id, :onboarding_template_id,
                                         :start_date, :end_date, :notes)
    end

    def current_organization
      current_employee.organization
    end
  end
end
