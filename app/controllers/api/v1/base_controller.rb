# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
    include Concerns::Serializable

    skip_before_action :verify_authenticity_token
    before_action :authenticate_employee!
    before_action :set_default_format

    # API responds with JSON, not HTML
    respond_to :json

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request

    private

    def set_default_format
      request.format = :json
    end

    def authorize_manager!
      unless current_employee.manager?
        render json: { error: 'Forbidden - Manager access required' }, status: :forbidden
      end
    end

    def authorize_hr!
      unless current_employee.hr_or_admin?
        render json: { error: 'Forbidden - HR access required' }, status: :forbidden
      end
    end

    def require_sirh_plan!
      unless current_employee.organization.sirh?
        render json: { error: 'Forbidden - SIRH plan required' }, status: :forbidden
      end
    end

    def not_found(exception)
      render json: { error: exception.message }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: {
        error: 'Validation failed',
        details: exception.record.errors.full_messages
      }, status: :unprocessable_entity
    end

    def bad_request(exception)
      render json: { error: exception.message }, status: :bad_request
    end

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        next_page: collection.next_page,
        prev_page: collection.prev_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count
      }
    end
    end
  end
end
