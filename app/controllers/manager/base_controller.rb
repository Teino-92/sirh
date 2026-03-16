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

    # Safe RulesEngine trigger — never breaks the main flow.
    def fire_rules_engine(event, resource, context = {})
      RulesEngine.new(current_organization).trigger(event, resource: resource, context: context)
    rescue => e
      Rails.logger.error("[RulesEngine] #{event} failed silently: #{e.message}")
    end
  end
end
