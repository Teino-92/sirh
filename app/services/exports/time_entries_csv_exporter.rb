# frozen_string_literal: true

module Exports
  class TimeEntriesCsvExporter < BaseCsvExporter
    def export
      headers = build_headers
      rows = build_rows

      {
        content: generate_csv(headers, rows),
        filename: filename('pointages')
      }
    end

    private

    def build_headers
      [
        'Nom',
        'Prénom',
        'Date',
        'Arrivée',
        'Départ',
        'Durée (heures)',
        'Retard (minutes)',
        'Heures supplémentaires',
        'Statut validation',
        'Validé par',
        'Date validation',
        'Notes'
      ]
    end

    def build_rows
      rows = []
      start_date, end_date = date_range

      team_members.find_each do |employee|
        time_entries = fetch_time_entries(employee, start_date, end_date)

        time_entries.each do |entry|
          rows << build_row(employee, entry)
        end
      end

      rows
    end

    def fetch_time_entries(employee, start_date, end_date)
      entries = employee.time_entries
                       .where('DATE(clock_in) BETWEEN ? AND ?', start_date, end_date)
                       .order(:clock_in)

      # Apply ActiveRecord filters first (before converting to array)
      if @filters[:only_unvalidated] == '1' || @filters[:only_unvalidated] == true
        if entries.respond_to?(:pending_validation)
          entries = entries.pending_validation
        else
          entries = entries.where(validation_status: 'pending')
        end
      end

      if @filters[:validation_status].present?
        case @filters[:validation_status]
        when 'pending'
          if entries.respond_to?(:pending_validation)
            entries = entries.pending_validation
          else
            entries = entries.where(validation_status: 'pending')
          end
        when 'validated'
          if entries.respond_to?(:validated)
            entries = entries.validated
          else
            entries = entries.where(validation_status: 'validated')
          end
        when 'rejected'
          if entries.respond_to?(:rejected)
            entries = entries.rejected
          else
            entries = entries.where(validation_status: 'rejected')
          end
        end
      end

      # Apply Ruby filters that require loading records (converts to array)
      if @filters[:only_late] == '1' || @filters[:only_late] == true
        entries = entries.to_a.select { |e| e.respond_to?(:late?) && e.late? }
      end

      entries
    end

    def build_row(employee, entry)
      [
        employee.last_name,
        employee.first_name,
        format_date(entry.worked_date),
        format_datetime(entry.clock_in),
        format_datetime(entry.clock_out),
        format_duration_hours(entry.duration_seconds),
        calculate_late_minutes(entry),
        calculate_overtime(entry),
        validation_status_text(entry),
        entry.validated_by&.full_name || '',
        format_datetime(entry.validated_at),
        entry.notes || ''
      ]
    end

    def calculate_late_minutes(entry)
      return '' unless entry.respond_to?(:late?) && entry.late?

      # Assuming schedule start time is stored or we have a method to get it
      # For now, return empty string as schedule is not fully implemented
      if entry.employee.work_schedule&.starts_at
        schedule_start = entry.employee.work_schedule.starts_at
        actual_start = entry.clock_in.strftime('%H:%M')

        # Simple calculation - needs work_schedule to be accurate
        late_seconds = entry.clock_in.seconds_since_midnight - schedule_start.seconds_since_midnight
        (late_seconds / 60).to_i.to_s if late_seconds > 0
      else
        ''
      end
    rescue StandardError
      ''
    end

    def calculate_overtime(entry)
      return '' unless entry.duration_seconds

      # French law: 35h per week, anything over 7h/day could be overtime
      # This is simplified - real calculation needs weekly context
      daily_limit = 7 * 3600 # 7 hours in seconds
      overtime_seconds = entry.duration_seconds - daily_limit

      if overtime_seconds > 0
        format_duration_hhmm(overtime_seconds)
      else
        ''
      end
    end

    def validation_status_text(entry)
      if entry.respond_to?(:validation_status)
        case entry.validation_status
        when 'pending'
          'En attente'
        when 'validated'
          'Validé'
        when 'rejected'
          'Refusé'
        else
          'Non validé'
        end
      else
        'Non validé'
      end
    end
  end
end
