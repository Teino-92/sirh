# frozen_string_literal: true

module Exports
  class BaseCsvExporter
    require 'csv'

    attr_reader :manager, :filters

    def initialize(manager, filters = {})
      @manager = manager
      @filters = filters
    end

    # Must be implemented by subclasses
    def export
      raise NotImplementedError, "#{self.class} must implement #export method"
    end

    private

    # Generate CSV with French Excel compatibility
    # - UTF-8 with BOM for proper encoding in Excel
    # - Semicolon separator (French Excel standard)
    # - Double quotes for text fields
    def generate_csv(headers, rows)
      CSV.generate(col_sep: ';', force_quotes: true, encoding: 'UTF-8') do |csv|
        # Add UTF-8 BOM for Excel compatibility
        csv << ["\uFEFF#{headers.first}"] + headers[1..-1]

        rows.each do |row|
          csv << row
        end
      end
    end

    # Format date to French format (JJ/MM/AAAA)
    def format_date(date)
      return '' if date.nil?
      date.strftime('%d/%m/%Y')
    end

    # Format datetime to French format (JJ/MM/AAAA HH:MM)
    def format_datetime(datetime)
      return '' if datetime.nil?
      datetime.in_time_zone('Paris').strftime('%d/%m/%Y %H:%M')
    end

    # Format duration in hours (e.g., "7.5" or "7h30")
    def format_duration_hours(seconds)
      return '' if seconds.nil? || seconds.zero?
      hours = seconds / 3600.0
      hours.round(2).to_s.sub('.', ',') # French decimal separator
    end

    # Format duration as HH:MM
    def format_duration_hhmm(seconds)
      return '' if seconds.nil? || seconds.zero?
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      format('%02d:%02d', hours, minutes)
    end

    # Get exportable employees based on the requester's role.
    # HR and admin see all org employees; managers see only their direct team.
    def team_members
      @team_members ||= begin
        members = if @manager.hr_or_admin?
                    @manager.organization.employees
                  else
                    @manager.team_members
                  end

        # Filter by specific employees if provided
        if @filters[:employee_ids].present?
          members = members.where(id: @filters[:employee_ids])
        end

        # Filter by department if provided
        if @filters[:department].present?
          members = members.where(department: @filters[:department])
        end

        members.order(:last_name, :first_name)
      end
    end

    # Parse date range from filters
    def date_range
      start_date = parse_start_date
      end_date = parse_end_date

      [start_date, end_date]
    end

    def parse_start_date
      if @filters[:start_date].present?
        Date.parse(@filters[:start_date])
      elsif @filters[:period] == 'this_week'
        Date.current.beginning_of_week
      elsif @filters[:period] == 'this_month'
        Date.current.beginning_of_month
      elsif @filters[:period] == 'last_month'
        1.month.ago.beginning_of_month
      elsif @filters[:period] == 'this_quarter'
        Date.current.beginning_of_quarter
      elsif @filters[:period] == 'this_year'
        Date.current.beginning_of_year
      else
        1.month.ago.to_date
      end
    end

    def parse_end_date
      if @filters[:end_date].present?
        Date.parse(@filters[:end_date])
      elsif @filters[:period] == 'this_week'
        Date.current.end_of_week
      elsif @filters[:period] == 'this_month'
        Date.current.end_of_month
      elsif @filters[:period] == 'last_month'
        1.month.ago.end_of_month
      elsif @filters[:period] == 'this_quarter'
        Date.current.end_of_quarter
      elsif @filters[:period] == 'this_year'
        Date.current.end_of_year
      else
        Date.current
      end
    end

    # Generate filename with timestamp and type
    def filename(type, extension = 'csv')
      start_date, end_date = date_range
      date_str = if start_date == end_date
                   format_date(start_date).tr('/', '-')
                 else
                   "#{format_date(start_date).tr('/', '-')}_au_#{format_date(end_date).tr('/', '-')}"
                 end

      "#{type}_equipe_#{date_str}.#{extension}"
    end
  end
end
