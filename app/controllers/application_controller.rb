# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Devise automatically creates current_employee based on the model name
  # No need to alias - just use current_employee everywhere

  # After sign in, redirect to dashboard
  def after_sign_in_path_for(resource)
    dashboard_path
  end
end
