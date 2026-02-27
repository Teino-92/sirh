# frozen_string_literal: true

class OnboardingsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_onboarding

  def show; end

  private

  def set_onboarding
    @onboarding = current_employee.organization.onboardings.find(params[:id])
    authorize @onboarding
  end
end
