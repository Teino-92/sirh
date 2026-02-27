# frozen_string_literal: true

require_dependency Rails.root.join('app', 'services', 'exports', 'base_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'time_entries_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'absences_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'one_on_ones_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'evaluations_csv_exporter')
require_dependency Rails.root.join('app', 'services', 'exports', 'trainings_csv_exporter')

module Manager
  class ExportsController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_manager!

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

    def one_on_ones
      authorize :exports, policy_class: ExportPolicy
      csv_export(Exports::OneOnOnesCsvExporter)
    end

    def evaluations
      authorize :exports, policy_class: ExportPolicy
      csv_export(Exports::EvaluationsCsvExporter)
    end

    def trainings
      authorize :exports, policy_class: ExportPolicy
      csv_export(Exports::TrainingsCsvExporter)
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

    def authorize_manager!
      unless current_employee.manager?
        redirect_to dashboard_path, alert: 'Accès réservé aux managers'
      end
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
  end
end
