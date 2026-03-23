# frozen_string_literal: true

module Admin
  class EmployeeImportsController < Admin::BaseController
    ALLOWED_CONTENT_TYPES = %w[
      text/csv
      text/plain
      application/csv
      application/vnd.ms-excel
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/octet-stream
    ].freeze

    ALLOWED_EXTENSIONS = %w[.csv .txt .xlsx .xls].freeze

    def new
      authorize :employee_import
    end

    def create
      authorize :employee_import
      file = params[:file]

      unless file.present?
        return redirect_to new_admin_employee_import_path,
                           alert: "Veuillez sélectionner un fichier."
      end

      ext = File.extname(file.original_filename.to_s).downcase
      unless ALLOWED_EXTENSIONS.include?(ext) || ALLOWED_CONTENT_TYPES.include?(file.content_type)
        return redirect_to new_admin_employee_import_path,
                           alert: "Format invalide. Formats acceptés : CSV, XLSX."
      end

      result = EmployeeCsvImportService.new(file, current_organization).call

      @imported   = result.imported
      @errors     = result.errors
      @skipped    = result.skipped
      @duplicates = result.duplicates

      render :result
    end
  end
end
