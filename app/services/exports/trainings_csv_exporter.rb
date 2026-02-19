# frozen_string_literal: true

module Exports
  class TrainingsCsvExporter < BaseCsvExporter
    STATUS_LABELS = {
      'assigned'    => 'Assignée',
      'in_progress' => 'En cours',
      'completed'   => 'Terminée',
      'cancelled'   => 'Annulée'
    }.freeze

    TYPE_LABELS = {
      'internal'      => 'Interne',
      'external'      => 'Externe',
      'certification' => 'Certification',
      'e_learning'    => 'E-learning',
      'mentoring'     => 'Mentorat'
    }.freeze

    def export
      start_date, end_date = date_range
      member_ids = team_members.pluck(:id)

      records = TrainingAssignment
                  .where(employee_id: member_ids)
                  .where(assigned_at: start_date..end_date)
                  .includes(:employee, :assigned_by, :training)
                  .order(assigned_at: :desc)

      if filters[:status].present?
        records = records.where(status: filters[:status])
      end

      headers = [
        'Employé', 'Formation', 'Type', 'Organisme', 'Durée (h)',
        'Statut', 'Assigné par', 'Assignée le', 'Échéance', 'Terminée le', 'Notes de complétion'
      ]

      rows = records.map do |ta|
        t = ta.training
        [
          "#{ta.employee.last_name} #{ta.employee.first_name}",
          t.title,
          TYPE_LABELS[t.training_type] || t.training_type,
          t.provider.to_s,
          t.duration_estimate.to_s.sub('.', ','),
          STATUS_LABELS[ta.status] || ta.status,
          "#{ta.assigned_by.last_name} #{ta.assigned_by.first_name}",
          format_date(ta.assigned_at),
          format_date(ta.deadline),
          format_datetime(ta.completed_at),
          ta.completion_notes.to_s.truncate(300)
        ]
      end

      content = generate_csv(headers, rows)

      {
        content: content,
        filename: filename('formations', 'csv')
      }
    end
  end
end
