# frozen_string_literal: true

module Api
  module V1
  class TimeEntriesController < BaseController
    # POST /api/v1/time_entries/clock_in
    def clock_in
      # Check if already clocked in
      if current_employee.time_entries.active.any?
        return render json: {
          error: 'Already clocked in',
          current_entry: current_employee.time_entries.active.first
        }, status: :unprocessable_entity
      end

      time_entry = current_employee.time_entries.create!(
        clock_in: Time.current,
        location: clock_params[:location] || {}
      )

      # Calculate expected clock out based on schedule
      schedule = current_employee.work_schedule
      today = Date.current.strftime('%A').downcase
      expected_hours = schedule&.hours_for_day(today) || 7

      render json: {
        entry: serialize_time_entry(time_entry),
        expected_clock_out: time_entry.clock_in + expected_hours.hours,
        message: 'Pointage effectué avec succès'
      }, status: :created
    end

    # POST /api/v1/time_entries/clock_out
    def clock_out
      time_entry = current_employee.time_entries.active.first

      unless time_entry
        return render json: { error: 'No active time entry found' }, status: :not_found
      end

      time_entry.clock_out!(
        time: Time.current,
        location: clock_params[:location]
      )

      render json: {
        entry: serialize_time_entry(time_entry),
        hours_worked: time_entry.hours_worked,
        overtime: time_entry.overtime?,
        message: 'Pointage de sortie effectué avec succès'
      }
    end

    # GET /api/v1/time_entries
    def index
      entries = current_employee.time_entries
                                 .order(clock_in: :desc)
                                 .limit(30)

      render json: {
        entries: entries.map { |e| serialize_time_entry(e) },
        summary: {
          this_week: weekly_summary,
          this_month: monthly_summary
        }
      }
    end

    # GET /api/v1/time_entries/:id
    def show
      entry = current_employee.time_entries.find(params[:id])
      render json: serialize_time_entry(entry)
    end

    private

    def clock_params
      params.permit(:location => {})
    end

    def weekly_summary
      entries = current_employee.time_entries.this_week.completed
      total_hours = entries.sum('duration_minutes') / 60.0

      {
        total_hours: total_hours.round(2),
        days_worked: entries.map(&:worked_date).uniq.count,
        overtime_hours: [total_hours - 35, 0].max.round(2)
      }
    end

    def monthly_summary
      entries = current_employee.time_entries.this_month.completed
      total_hours = entries.sum('duration_minutes') / 60.0
      expected_hours = current_employee.work_schedule&.weekly_hours.to_f * 4.33

      {
        total_hours: total_hours.round(2),
        days_worked: entries.map(&:worked_date).uniq.count,
        expected_hours: expected_hours.round(2),
        overtime_hours: [total_hours - expected_hours, 0].max.round(2)
      }
    end
  end
  end
end
