# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include ActsAsTenant::ControllerExtensions

  # Protect staging from public access and search engine indexing
  if Rails.env.staging?
    http_basic_authenticate_with(
      name:     ENV.fetch('STAGING_LOGIN',    'staging'),
      password: ENV.fetch('STAGING_PASSWORD', 'staging')
    )
  end

  # Set tenant for multi-tenancy
  before_action :set_tenant
  before_action :check_trial_expired!, if: :employee_signed_in?

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

  def check_trial_expired!
    org = current_employee.organization
    return unless org.trial_expired?
    return if devise_controller?
    return if controller_path.in?(%w[trial_expired billings stripe_webhooks])

    billing = BillingService.new(org)
    if billing.needs_subscription?
      redirect_to billing_path
    else
      redirect_to trial_expired_path
    end
  end

  def user_not_authorized
    flash[:alert] = "Vous n'êtes pas autorisé à effectuer cette action."
    redirect_back(fallback_location: dashboard_path)
  end

  # Lograge payload — appended to every structured log line
  def append_info_to_payload(payload)
    super
    payload[:current_user_id] = current_employee&.id
    payload[:current_org_id]  = current_employee&.organization_id
  end
end
