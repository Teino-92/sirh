# frozen_string_literal: true

module Manager
  class BaseController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_manager!

    private

    def authorize_manager!
      unless current_employee.manager?
        redirect_to root_path, alert: 'Accès non autorisé'
      end
    end

    def current_organization
      current_employee.organization
    end
  end
end
