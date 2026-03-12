# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include ActsAsTenant::ControllerExtensions

  # Set tenant for multi-tenancy
  before_action :set_tenant

  # Pundit will use current_employee instead of current_user
  def pundit_user
    current_employee
  end

  # Handle authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # After sign in, redirect to dashboard
  def after_sign_in_path_for(resource)
    dashboard_path
  end

  private

  def set_tenant
    if current_employee
      ActsAsTenant.current_tenant = current_employee.organization
    else
      # No tenant scoping on public/Devise pages — Devise must find employees across all orgs
      ActsAsTenant.current_tenant = nil
    end
  end

  def user_not_authorized
    flash[:alert] = "Vous n'êtes pas autorisé à effectuer cette action."
    redirect_back(fallback_location: dashboard_path)
  end
end
