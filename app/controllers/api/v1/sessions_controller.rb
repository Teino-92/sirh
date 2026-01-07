# frozen_string_literal: true

module Api
  module V1
    class SessionsController < BaseController
    skip_before_action :authenticate_employee!, only: [:create]

    # POST /api/v1/login
    def create
      employee = Employee.find_by(email: params[:email])

      if employee&.valid_password?(params[:password])
        # Sign in the employee to trigger JWT token generation
        sign_in employee

        render json: {
          message: 'Logged in successfully',
          employee: {
            id: employee.id,
            email: employee.email,
            first_name: employee.first_name,
            last_name: employee.last_name,
            role: employee.role,
            organization: {
              id: employee.organization_id,
              name: employee.organization.name
            }
          }
        }, status: :ok
      else
        render json: { error: 'Invalid email or password' }, status: :unauthorized
      end
    end

    # POST /api/v1/refresh
    # Refresh JWT token without re-authenticating
    # Client must provide valid (non-expired) token in Authorization header
    def refresh
      # Current employee is already authenticated via JWT
      # Devise JWT will automatically issue a new token in the response header
      render json: {
        message: 'Token refreshed successfully',
        employee: {
          id: current_employee.id,
          email: current_employee.email,
          first_name: current_employee.first_name,
          last_name: current_employee.last_name
        }
      }, status: :ok
    end

    # DELETE /api/v1/logout
    def destroy
      # Devise JWT will automatically revoke the token via the denylist
      render json: { message: 'Logged out successfully' }, status: :ok
    end
    end
  end
end
