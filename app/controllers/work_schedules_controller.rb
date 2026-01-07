# frozen_string_literal: true

class WorkSchedulesController < ApplicationController
  before_action :authenticate_employee!

  def show
    @employee = current_employee
    @work_schedule = @employee.work_schedule || WorkSchedule.new(employee: @employee)
    authorize @work_schedule

    # Calendar month navigation
    @current_date = params[:date]&.to_date || Date.current
    @start_date = @current_date.beginning_of_month
    @end_date = @current_date.end_of_month

    # Get approved leaves for this month
    @leaves = @employee.leave_requests
                       .approved
                       .for_date_range(@start_date, @end_date)
                       .order(:start_date)

    # Get time entries for this month (to show actual worked hours)
    @time_entries = @employee.time_entries
                             .where('DATE(clock_in) BETWEEN ? AND ?', @start_date, @end_date)
                             .completed
                             .order(:clock_in)

    # Get weekly schedule plans for this month
    @weekly_plans = @employee.weekly_schedule_plans
                             .where('week_start_date BETWEEN ? AND ?', @start_date.beginning_of_week, @end_date)
                             .index_by(&:week_start_date)

    # Build calendar data structure
    @calendar_weeks = build_calendar_weeks(@start_date, @end_date)
  end

  def edit
    @work_schedule = current_employee.work_schedule

    unless @work_schedule
      redirect_to work_schedule_path(current_employee.work_schedule || 1), alert: 'Horaire non trouvé'
      return
    end

    authorize @work_schedule
  end

  def update
    @work_schedule = current_employee.work_schedule
    authorize @work_schedule

    if @work_schedule.update(work_schedule_params)
      redirect_to work_schedule_path(@work_schedule), notice: 'Horaire mis à jour avec succès'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def build_calendar_weeks(start_date, end_date)
    weeks = []
    current_week = []

    # Start from the Monday before the first day of the month
    date = start_date.beginning_of_week(:monday)

    # End on the Sunday after the last day of the month
    end_loop = end_date.end_of_week(:sunday)

    while date <= end_loop
      current_week << {
        date: date,
        in_current_month: date.month == start_date.month,
        is_today: date == Date.current
      }

      if date.wday == 0 # Sunday
        weeks << current_week
        current_week = []
      end

      date += 1.day
    end

    weeks << current_week unless current_week.empty?
    weeks
  end

  def work_schedule_params
    params.require(:work_schedule).permit(:schedule_pattern, :weekly_hours)
  end
end
