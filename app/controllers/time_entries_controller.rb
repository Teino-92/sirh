# frozen_string_literal: true

class TimeEntriesController < ApplicationController
  before_action :authenticate_employee!

  def index
    # Employee can only see their own time entries
    @employee = current_employee
    @current_shift = @employee.time_entries.active.first

    # Filter by period (default to week)
    period = params[:period] == 'month' ? :this_month : :this_week
    @time_entries = policy_scope(TimeEntry).where(employee: @employee).send(period).order(clock_in: :asc)

    # Calculate hours
    @weekly_hours = weekly_hours
    @monthly_hours = monthly_hours
    @expected_weekly_hours = @employee.work_schedule&.weekly_hours || 35
    @expected_monthly_hours = @expected_weekly_hours * 4.33

    # Group by day for summary
    @time_entries_by_day = @time_entries.completed.group_by(&:worked_date)

    # Complementary hours warning for part-time employees
    if @employee.work_schedule&.part_time?
      @complementary_hours = ComplementaryHoursCalculatorService.new(
        @employee,
        week_start: Date.current.beginning_of_week
      ).call
    end
  end

  def clock_in
    @entry = current_employee.time_entries.build(clock_in: Time.current)
    authorize @entry, :clock_in?

    if current_employee.time_entries.active.any?
      redirect_to time_entries_path, alert: 'Vous êtes déjà pointé(e)'
      return
    end

    @entry.save!

    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: 'Pointage effectué avec succès' }
      format.turbo_stream
    end
  end

  def clock_out
    @entry = current_employee.time_entries.active.first

    unless @entry
      redirect_to time_entries_path, alert: 'Aucun pointage actif trouvé'
      return
    end

    authorize @entry, :clock_out?
    @entry.clock_out!

    respond_to do |format|
      format.html { redirect_to dashboard_path, notice: 'Pointage de sortie effectué avec succès' }
      format.turbo_stream
    end
  end

  private

  def weekly_hours
    current_employee.time_entries.this_week.completed.sum('duration_minutes') / 60.0
  end

  def monthly_hours
    current_employee.time_entries.this_month.completed.sum('duration_minutes') / 60.0
  end
end
