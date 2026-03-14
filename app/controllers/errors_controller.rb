# frozen_string_literal: true

class ErrorsController < ApplicationController
  layout 'errors'

  # Error pages must render even without a valid session / tenant
  skip_before_action :authenticate_employee!, raise: false
  skip_before_action :check_trial_expired!,   raise: false

  def not_found
    render status: :not_found
  end

  def unprocessable_entity
    render status: :unprocessable_entity
  end

  def internal_server_error
    render status: :internal_server_error
  end
end
