# frozen_string_literal: true

module Api
  module V1
    class LeaveBalancesController < BaseController
      # GET /api/v1/leave_balances
      def index
        balances = current_employee.leave_balances.order(:leave_type)

        render json: {
          balances: balances.map { |b| serialize_leave_balance(b) },
          total_available: balances.sum(&:balance)
        }
      end
    end
  end
end
