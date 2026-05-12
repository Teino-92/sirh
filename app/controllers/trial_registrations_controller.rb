# frozen_string_literal: true

class TrialRegistrationsController < ApplicationController
  skip_before_action :authenticate_employee!, raise: false
  layout 'marketing'

  def new
    @form_values = {}
    @errors = []
  end

  def create
    result = TrialRegistrationService.new(trial_params).call

    if result.success?
      redirect_to new_employee_session_path,
        notice: "Votre espace est créé ! Un email vous a été envoyé à #{result.employee.email} pour définir votre mot de passe."
    else
      @errors      = result.errors
      @form_values = trial_params.to_h
      render 'pages/home', status: :unprocessable_entity
    end
  end

  private

  def trial_params
    params.require(:trial).permit(:organization_name, :first_name, :last_name, :email, :plan)
  end
end
