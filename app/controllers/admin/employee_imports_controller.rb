# frozen_string_literal: true

module Admin
  class EmployeeImportsController < Admin::BaseController
    ALLOWED_CONTENT_TYPES = %w[
      text/csv
      text/plain
      application/csv
      application/vnd.ms-excel
      application/octet-stream
    ].freeze

    def new
      # Affiche le formulaire upload + template téléchargeable
    end

    def create
      file = params[:file]

      unless file.present?
        return redirect_to new_admin_employee_import_path,
                           alert: "Veuillez sélectionner un fichier CSV."
      end

      unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
        return redirect_to new_admin_employee_import_path,
                           alert: "Format invalide. Veuillez uploader un fichier CSV."
      end

      result = EmployeeCsvImportService.new(file, current_organization).call

      @imported = result.imported
      @errors   = result.errors
      @skipped  = result.skipped

      render :result
    end
  end
end
