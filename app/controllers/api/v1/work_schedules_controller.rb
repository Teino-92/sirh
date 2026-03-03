# frozen_string_literal: true

module Api
  module V1
    class WorkSchedulesController < BaseController
      before_action :set_work_schedule

      # GET /api/v1/work_schedules/:id
      def show
        render json: serialize_work_schedule(@work_schedule)
      end

      # PATCH /api/v1/work_schedules/:id
      def update
        if @work_schedule.update(work_schedule_params)
          render json: serialize_work_schedule(@work_schedule)
        else
          render json: {
            error: 'Validation failed',
            details: @work_schedule.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_work_schedule
        @work_schedule = current_employee.work_schedule ||
                         raise(ActiveRecord::RecordNotFound, 'Work schedule not found')
        # Employees can only access their own schedule; managers their own too.
        # HR/admin have access via admin UI, not this endpoint.
        raise ActiveRecord::RecordNotFound unless @work_schedule.id == params[:id].to_i
      end

      def work_schedule_params
        params.require(:work_schedule).permit(:name, :weekly_hours, schedule_pattern: {})
      end
    end
  end
end
