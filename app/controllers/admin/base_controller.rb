# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_admin!

    layout 'admin'

    private

    def authorize_admin!
      unless current_employee.hr_or_admin?
        redirect_to root_path, alert: 'Accès non autorisé'
      end
    end
  end
end
