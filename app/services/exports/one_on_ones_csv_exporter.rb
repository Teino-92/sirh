# frozen_string_literal: true

module Exports
  class OneOnOnesCsvExporter < BaseCsvExporter
    STATUS_LABELS = {
      'scheduled'   => 'Planifié',
      'completed'   => 'Complété',
      'cancelled'   => 'Annulé',
      'rescheduled' => 'Reporté'
    }.freeze

    def export
      start_date, end_date = date_range
      member_ids = team_members.pluck(:id)

      records = OneOnOne
                  .where(employee_id: member_ids)
                  .where('scheduled_at BETWEEN ? AND ?', start_date.beginning_of_day, end_date.end_of_day)
                  .includes(:employee, :manager)
                  .order(:scheduled_at)

      if filters[:status].present?
        records = records.where(status: filters[:status])
      end

      headers = [
        'Employé', 'Manager', 'Statut', 'Planifié le',
        'Terminé le', 'Ordre du jour', 'Notes', 'Éléments d\'action'
      ]

      rows = records.map do |r|
        action_count = r.respond_to?(:action_items) ? r.action_items.size : 0
        [
          "#{r.employee.last_name} #{r.employee.first_name}",
          "#{r.manager.last_name} #{r.manager.first_name}",
          STATUS_LABELS[r.status] || r.status,
          format_datetime(r.scheduled_at),
          format_datetime(r.completed_at),
          r.agenda.to_s.truncate(200),
          r.notes.to_s.truncate(200),
          action_count
        ]
      end

      content = generate_csv(headers, rows)

      {
        content: content,
        filename: filename('1on1', 'csv')
      }
    end
  end
end
