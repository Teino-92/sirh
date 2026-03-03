# frozen_string_literal: true

require_dependency Rails.root.join('app', 'services', 'exports', 'base_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'time_entries_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'absences_csv_exporter')

module Manager
  class ExportsController < BaseController

    def index
      authorize :exports, policy_class: ExportPolicy
    end

    def time_entries
      authorize :exports, policy_class: ExportPolicy
      csv_export(Exports::TimeEntriesCsvExporter)
    end

    def absences
      authorize :exports, policy_class: ExportPolicy
      csv_export(Exports::AbsencesCsvExporter)
    end

    def search
      authorize :exports, policy_class: ExportPolicy
      @query = params[:query].to_s.strip
      if @query.blank?
        @search_error = "Veuillez saisir une requête."
        return render :index, status: :unprocessable_entity
      end
      result = HrQuery::HrQueryInterpreterService.new(@query).call
      if result.success
        @filters       = result.filters
        @rows          = HrQuery::HrQueryExecutorService.new(@filters, current_employee).call
        @columns       = column_labels(@rows)
        @filters_param = @filters.to_json
      else
        @search_error = result.error
      end
      render :index
    end

    def search_export
      authorize :exports, policy_class: ExportPolicy
      filters = JSON.parse(params[:filters].to_s)
      result  = HrQuery::HrQueryCsvExporter.new(current_employee, filters).export
      send_data result[:content], filename: result[:filename],
                type: 'text/csv; charset=utf-8', disposition: 'attachment'
    rescue JSON::ParserError
      redirect_to manager_exports_path, alert: "Paramètres invalides."
    end

    private

    def csv_export(exporter_class)
      exporter = exporter_class.new(current_employee, export_params)
      result = exporter.export

      send_data result[:content],
                filename: result[:filename],
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue StandardError => e
      Rails.logger.error "Export CSV error: #{e.message}"
      redirect_to manager_exports_path, alert: "Erreur lors de l'export: #{e.message}"
    end

    def export_params
      params.permit(
        :start_date,
        :end_date,
        :period,
        :department,
        :only_late,
        :only_unvalidated,
        :only_unjustified,
        :validation_status,
        :status,
        employee_ids: [],
        leave_types: []
      ).to_h
    end

    COLUMN_LABELS = HrQuery::HrQueryCsvExporter::COLUMN_LABELS

    def column_labels(rows)
      return {} if rows.empty?
      rows.first.keys.each_with_object({}) do |key, h|
        h[key] = COLUMN_LABELS.fetch(key, key.humanize)
      end
    end
  end
end
