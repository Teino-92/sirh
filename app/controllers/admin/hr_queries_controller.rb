# frozen_string_literal: true

module Admin
  class HrQueriesController < Admin::BaseController
    def show
      authorize :hr_query, :show?
    end

    # POST /admin/hr_query
    # Responds with a Turbo Stream that replaces the results frame.
    def create
      authorize :hr_query, :create?

      @query = params[:query].to_s.strip

      if @query.blank?
        @error = "Veuillez saisir une requête."
        return render :show
      end

      result = HrQuery::HrQueryInterpreterService.new(@query).call

      if result.success
        @filters       = result.filters
        @rows          = HrQuery::HrQueryExecutorService.new(@filters, current_employee).call
        @columns       = column_labels(@rows)
        @filters_param = @filters.to_json
      else
        @error = result.error
      end

      render :show
    end

    # GET /admin/hr_query/export?filters=...
    def export
      authorize :hr_query, :export?

      filters_json = params[:filters].to_s
      if filters_json.blank?
        redirect_to admin_hr_query_path, alert: "Aucun filtre fourni pour l'export."
        return
      end

      filters = JSON.parse(filters_json)
      exporter = HrQuery::HrQueryCsvExporter.new(current_employee, filters)
      result   = exporter.export

      send_data result[:content],
                filename: result[:filename],
                type: "text/csv; charset=utf-8",
                disposition: "attachment"
    rescue JSON::ParserError
      redirect_to admin_hr_query_path, alert: "Paramètres de filtres invalides."
    end

    private

    COLUMN_LABELS = HrQuery::HrQueryCsvExporter::COLUMN_LABELS

    def column_labels(rows)
      return {} if rows.empty?
      rows.first.keys.each_with_object({}) do |key, h|
        h[key] = COLUMN_LABELS.fetch(key, key.humanize)
      end
    end
  end
end
