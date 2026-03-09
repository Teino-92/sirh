# frozen_string_literal: true

class TrialRegistrationsController < ApplicationController
  skip_before_action :authenticate_employee!, raise: false
  layout 'marketing'

  def create
    result = TrialRegistrationService.new(trial_params).call

    if result.success?
      sign_in(:employee, result.employee)
      redirect_to authenticated_root_path,
        notice: "Bienvenue sur Izi-RH ! Votre espace est prêt. 🎉"
    else
      @errors      = result.errors
      @form_values = trial_params.to_h
      render 'pages/home', status: :unprocessable_entity
    end
  end

  private

  def trial_params
    params.require(:trial).permit(:organization_name, :first_name, :last_name, :email)
  end
end
