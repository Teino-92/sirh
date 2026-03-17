# frozen_string_literal: true

module Manager
  class OnboardingTemplatesController < BaseController
    def create
      @template = OnboardingTemplate.new(template_params)
      @template.organization = current_organization
      authorize @template, policy_class: OnboardingTemplatePolicy

      if @template.save
        redirect_to manager_employee_onboardings_path,
                    notice: "Modèle « #{@template.name} » créé. Vous pouvez maintenant démarrer un onboarding."
      else
        redirect_to manager_employee_onboardings_path,
                    alert: @template.errors.full_messages.to_sentence
      end
    end

    private

    def template_params
      params.require(:onboarding_template).permit(:name, :description, :duration_days, :active)
    end
  end
end
