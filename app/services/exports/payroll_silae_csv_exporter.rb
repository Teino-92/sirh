# frozen_string_literal: true

module Exports
  # Generates a CSV in Silae/ADP-compatible format for payroll integration.
  #
  # Contains NIR and IBAN in clear text — every export is logged in AuditLog.
  # Only HR/admin can trigger this export (enforced by PayrollPolicy#export_silae?).
  #
  # @param requester [Employee]  HR/admin running the export
  # @param period    [Date]      Any date in the target month
  class PayrollSilaeCsvExporter < BaseCsvExporter
    HEADERS = [
      'Matricule',
      'NIR',
      'Nom',
      'Prénom',
      'Date de naissance',
      'Ville de naissance',
      'Département de naissance',
      'Nationalité',
      'IBAN',
      'BIC',
      'Type de contrat',
      'Convention collective (IDCC)',
      'Qualification',
      'Coefficient',
      'Date d\'entrée',
      'Taux temps partiel',
      'Salaire brut mensuel (€)',
      'Part variable mensuelle (€)',
      'Heures contractuelles / mois',
      'Heures pointées / mois',
      'Heures sup 25%',
      'Heures sup 50%',
      'Jours CP pris',
      'Jours RTT pris',
      'Jours maladie',
      'Jours sans solde',
      'Département RH',
      'Cadre',
      'Manager'
    ].freeze

    def initialize(requester, period)
      super(requester, {})
      @period = period.beginning_of_month
    end

    def export
      employees = @manager.organization.employees.active
                          .includes(:work_schedule, :manager)
                          .order(:last_name, :first_name)

      employee_ids = employees.map(&:id)

      # Bulk-load time entries and leave requests to avoid N+1 in PayrollCalculatorService
      time_entries_by_employee  = preload_time_entries(employee_ids)
      leave_requests_by_employee = preload_leave_requests(employee_ids)

      rows = employees.map do |emp|
        build_row(
          emp,
          time_entries:  time_entries_by_employee[emp.id]  || [],
          leave_requests: leave_requests_by_employee[emp.id] || []
        )
      end

      {
        content:  generate_csv(HEADERS, rows),
        filename: "silae_#{@period.strftime('%Y-%m')}_#{Date.current.strftime('%Y%m%d_%H%M')}.csv"
      }
    end

    private

    def preload_time_entries(employee_ids)
      TimeEntry
        .where(employee_id: employee_ids)
        .validated
        .where('clock_in >= ? AND clock_in < ?', @period, @period.next_month)
        .group_by(&:employee_id)
    end

    def preload_leave_requests(employee_ids)
      LeaveRequest
        .where(employee_id: employee_ids)
        .where(status: %w[approved auto_approved])
        .where('start_date <= ? AND end_date >= ?', @period.end_of_month, @period)
        .group_by(&:employee_id)
    end

    def build_row(emp, time_entries:, leave_requests:)
      calc = Payroll::PayrollCalculatorService.new(
        emp, @period,
        preloaded_time_entries:  time_entries,
        preloaded_leave_requests: leave_requests
      ).call

      [
        emp.id.to_s,
        emp.nir.to_s,
        emp.last_name.to_s,
        emp.first_name.to_s,
        format_date(emp.birth_date),
        emp.birth_city.to_s,
        emp.birth_department.to_s,
        emp.nationality.to_s,
        emp.iban.to_s,
        emp.bic.to_s,
        emp.contract_type.to_s,
        emp.convention_collective.to_s,
        emp.qualification.to_s,
        emp.coefficient.to_s,
        format_date(emp.start_date),
        format_decimal(emp.part_time_rate || 1.0),
        format_decimal(emp.gross_salary),
        format_decimal(emp.variable_pay),
        format_decimal(calc[:contractual_hours]),
        format_decimal(calc[:worked_hours]),
        format_decimal(calc[:overtime_25]),
        format_decimal(calc[:overtime_50]),
        format_decimal(calc[:leave_days_cp]),
        format_decimal(calc[:leave_days_rtt]),
        format_decimal(calc[:leave_days_sick]),
        format_decimal(calc[:leave_deduction]),
        emp.department.to_s,
        emp.cadre? ? 'Oui' : 'Non',
        emp.manager&.full_name.to_s
      ]
    end

    def format_decimal(value)
      return '' if value.nil?
      format('%.2f', value).sub('.', ',')
    end
  end
end
