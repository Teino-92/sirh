# frozen_string_literal: true

module Exports
  class EvaluationsCsvExporter < BaseCsvExporter
    STATUS_LABELS = {
      'draft'                   => 'Brouillon',
      'employee_review_pending' => 'Auto-évaluation attendue',
      'manager_review_pending'  => 'En cours d\'évaluation',
      'completed'               => 'Complétée',
      'cancelled'               => 'Annulée'
    }.freeze

    def export
      start_date, end_date = date_range
      member_ids = team_members.pluck(:id)

      records = Evaluation
                  .where(employee_id: member_ids)
                  .where(period_end: start_date..end_date)
                  .includes(:employee, :manager)
                  .order(period_end: :desc)

      if filters[:status].present?
        records = records.where(status: filters[:status])
      end

      headers = [
        'Employé', 'Manager', 'Statut', 'Période début', 'Période fin',
        'Score moyen', 'Auto-évaluation', 'Avis manager', 'Terminée le'
      ]

      rows = records.map do |e|
        avg = e.average_score
        [
          "#{e.employee.last_name} #{e.employee.first_name}",
          "#{e.manager.last_name} #{e.manager.first_name}",
          STATUS_LABELS[e.status] || e.status,
          format_date(e.period_start),
          format_date(e.period_end),
          avg ? avg.to_s.sub('.', ',') : '',
          e.self_review.to_s.truncate(300),
          e.manager_review.to_s.truncate(300),
          format_datetime(e.completed_at)
        ]
      end

      content = generate_csv(headers, rows)

      {
        content: content,
        filename: filename('evaluations', 'csv')
      }
    end
  end
end
