# frozen_string_literal: true

module Exports
  class AbsencesCsvExporter < BaseCsvExporter
    def export
      headers = build_headers
      rows = build_rows

      {
        content: generate_csv(headers, rows),
        filename: filename('absences')
      }
    end

    private

    def build_headers
      [
        'Nom',
        'Prénom',
        'Type d\'absence',
        'Date début',
        'Date fin',
        'Nombre de jours',
        'Statut',
        'Approuvé par',
        'Date d\'approbation',
        'Solde CP restant',
        'Solde RTT restant',
        'Motif / Raison'
      ]
    end

    def build_rows
      rows = []
      start_date, end_date = date_range

      team_members.find_each do |employee|
        leave_requests = fetch_leave_requests(employee, start_date, end_date)

        leave_requests.each do |request|
          rows << build_row(employee, request)
        end
      end

      rows
    end

    def fetch_leave_requests(employee, start_date, end_date)
      requests = employee.leave_requests
                        .where('start_date <= ? AND end_date >= ?', end_date, start_date)
                        .order(:start_date)

      # Apply filters
      if @filters[:leave_types].present?
        requests = requests.where(leave_type: @filters[:leave_types])
      end

      if @filters[:status].present?
        requests = requests.where(status: @filters[:status])
      end

      if @filters[:only_unjustified] == '1' || @filters[:only_unjustified] == true
        # Unjustified absences would be tracked differently
        # For now, we can filter for rejected or specific leave types
        # This would need a proper "unjustified_absence" type or status
      end

      requests
    end

    def build_row(employee, request)
      [
        employee.last_name,
        employee.first_name,
        leave_type_display(request.leave_type),
        format_date(request.start_date),
        format_date(request.end_date),
        request.days_count.to_s.sub('.', ','),
        status_display(request.status),
        request.approved_by&.full_name || '',
        format_datetime(request.approved_at),
        current_cp_balance(employee),
        current_rtt_balance(employee),
        request.rejection_reason || ''
      ]
    end

    def leave_type_display(leave_type)
      types = {
        'CP' => 'Congés Payés',
        'RTT' => 'RTT',
        'Maladie' => 'Maladie',
        'Maternite' => 'Maternité',
        'Paternite' => 'Paternité',
        'Sans_Solde' => 'Sans Solde',
        'Anciennete' => 'Congés Ancienneté'
      }
      types[leave_type] || leave_type
    end

    def status_display(status)
      statuses = {
        'pending' => 'En attente',
        'approved' => 'Approuvé',
        'rejected' => 'Refusé',
        'cancelled' => 'Annulé',
        'auto_approved' => 'Auto-approuvé'
      }
      statuses[status] || status
    end

    def current_cp_balance(employee)
      cp_balance = employee.leave_balances.find_by(leave_type: 'CP')
      return '' unless cp_balance

      cp_balance.balance.to_s.sub('.', ',')
    end

    def current_rtt_balance(employee)
      rtt_balance = employee.leave_balances.find_by(leave_type: 'RTT')
      return '' unless rtt_balance

      rtt_balance.balance.to_s.sub('.', ',')
    end
  end
end
