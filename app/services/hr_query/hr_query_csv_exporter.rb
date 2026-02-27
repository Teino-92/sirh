# frozen_string_literal: true

module HrQuery
  # Generates a CSV export from HR query results.
  # Extends the shared BaseCsvExporter for consistent French CSV formatting.
  #
  # SECURITY: salary column is re-checked here independently of the LLM output.
  class HrQueryCsvExporter < Exports::BaseCsvExporter
    COLUMN_LABELS = {
      "name"               => "Nom",
      "department"         => "Département",
      "role"               => "Rôle",
      "contract_type"      => "Type de contrat",
      "job_title"          => "Poste",
      "start_date"         => "Date d'entrée",
      "tenure_months"      => "Ancienneté (mois)",
      "leave_days_used"    => "Jours de congé consommés",
      "leave_type"         => "Type de congé",
      "evaluation_score"   => "Score d'évaluation",
      "evaluation_status"  => "Statut d'évaluation",
      "onboarding_status"  => "Statut onboarding",
      "integration_score"  => "Score d'intégration",
      "salary"             => "Salaire brut mensuel"
    }.freeze

    # @param requester [Employee] The HR/admin running the export
    # @param filters   [Hash]    Parsed filter JSON from the interpreter
    def initialize(requester, filters)
      super(requester, {})
      @hr_filters = filters.with_indifferent_access
    end

    def export
      rows      = HrQueryExecutorService.new(@hr_filters, @manager).call
      columns   = extract_columns(rows)
      headers   = columns.map { |c| COLUMN_LABELS.fetch(c, c) }
      csv_rows  = rows.map { |row| columns.map { |c| row[c].to_s } }

      {
        content:  generate_csv(headers, csv_rows),
        filename: "requete_rh_#{Date.current.strftime('%Y%m%d_%H%M')}.csv"
      }
    end

    private

    def extract_columns(rows)
      return [] if rows.empty?
      # Use keys from the first row; if salary is present but requester can't see it, strip it
      cols = rows.first.keys
      cols.delete("salary") unless @manager.hr_or_admin?
      cols
    end
  end
end
