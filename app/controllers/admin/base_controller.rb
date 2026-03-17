# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_admin!

    layout 'admin'

    helper_method :current_organization

    private

    def authorize_admin!
      unless current_employee.hr_or_admin? &&
             (current_employee.organization.sirh? || current_employee.organization.manager_os?)
        redirect_to root_path, alert: 'Accès non autorisé'
      end
    end

    def current_organization
      current_employee.organization
    end
  end
end
