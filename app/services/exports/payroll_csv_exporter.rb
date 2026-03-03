# frozen_string_literal: true

module Exports
  class PayrollCsvExporter < BaseCsvExporter
    def export
      {
        content: generate_csv(build_headers, build_rows),
        filename: filename('masse_salariale')
      }
    end

    private

    def build_headers
      [
        'Nom',
        'Prénom',
        'Poste',
        'Type de contrat',
        'Département',
        'Cadre',
        'Date d\'entrée',
        'Ancienneté (mois)',
        'Salaire brut mensuel (€)',
        'Part variable mensuelle (€)',
        'Taux de charges',
        'Coût employeur mensuel (€)',
        'Coût annuel estimé (€)'
      ]
    end

    def build_rows
      manager.organization.employees.active.order(:last_name, :first_name).map do |emp|
        tenure_months = ((Date.current - emp.start_date) / 30).to_i
        gross         = emp.gross_salary_cents / 100.0
        variable      = emp.variable_pay_cents  / 100.0
        rate          = emp.employer_charges_rate
        employer_monthly = (gross + variable) * rate
        annual           = employer_monthly * 12

        [
          emp.last_name,
          emp.first_name,
          emp.job_title.presence || '',
          emp.contract_type.to_s,
          emp.department.presence || '',
          emp.settings.fetch('cadre', false) ? 'Oui' : 'Non',
          format_date(emp.start_date),
          tenure_months.to_s,
          format_currency(gross),
          format_currency(variable),
          rate.to_s.sub('.', ','),
          format_currency(employer_monthly),
          format_currency(annual)
        ]
      end
    end

    def format_currency(amount)
      format('%.2f', amount).sub('.', ',')
    end

    # Payroll export is org-wide — no date range concept, no team_members scoping.
    # Override filename to omit period.
    def filename(_type, extension = 'csv')
      "masse_salariale_#{Date.current.strftime('%Y-%m-%d')}.#{extension}"
    end
  end
end
