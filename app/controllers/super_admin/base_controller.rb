# frozen_string_literal: true

module SuperAdmin
  class BaseController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_super_admin!

    layout 'admin'

    private

    def authorize_super_admin!
      allowed = ENV.fetch('SUPER_ADMIN_EMAIL', 'matteo.garbugli@yahoo.it')
                   .split(',')
                   .map(&:strip)
      unless allowed.include?(current_employee.email)
        redirect_to root_path, alert: 'Accès non autorisé'
      end
    end
  end
end
