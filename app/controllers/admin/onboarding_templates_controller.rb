# frozen_string_literal: true

module Admin
  class OnboardingTemplatesController < BaseController
    before_action :set_template, only: [:show, :edit, :update, :destroy]

    def index
      @templates = current_employee.organization.onboarding_templates.ordered
    end

    def show
      @tasks = @template.onboarding_template_tasks.ordered
    end

    def new
      @template = OnboardingTemplate.new
      authorize @template, policy_class: OnboardingTemplatePolicy
    end

    def create
      @template = OnboardingTemplate.new(template_params)
      @template.organization = current_employee.organization
      authorize @template, policy_class: OnboardingTemplatePolicy

      if @template.save
        redirect_to admin_onboarding_template_path(@template),
                    notice: 'Modèle créé avec succès.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @template.update(template_params)
        redirect_to admin_onboarding_template_path(@template),
                    notice: 'Modèle mis à jour.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @template.destroy
      redirect_to admin_onboarding_templates_path, notice: 'Modèle supprimé.'
    end

    private

    def set_template
      @template = current_employee.organization.onboarding_templates.find(params[:id])
      authorize @template, policy_class: OnboardingTemplatePolicy
    end

    def template_params
      params.require(:onboarding_template).permit(:name, :description, :duration_days, :active)
    end
  end
end
