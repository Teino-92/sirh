# frozen_string_literal: true

module Admin
  class PayrollController < BaseController
    def export
      authorize :payroll, policy_class: PayrollPolicy
      exporter = Exports::PayrollCsvExporter.new(current_employee)
      result   = exporter.export

      send_data result[:content],
                filename: result[:filename],
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue StandardError => e
      Rails.logger.error "Payroll CSV export error: #{e.message}"
      redirect_to admin_payroll_path, alert: "Une erreur est survenue lors de l'export. Contactez l'administrateur."
    end

    def push_silae
      authorize :payroll, :push_silae?

      period = Date.strptime(params[:period], '%Y-%m').beginning_of_month

      unless current_employee.organization.payroll_periods
                             .exists?(period: period)
        return redirect_to admin_payroll_path,
                           alert: "La période #{l(period, format: '%B %Y')} n'est pas clôturée. Clôturez-la avant d'envoyer."
      end

      unless current_employee.organization.payroll_webhook_url.present?
        return redirect_to admin_payroll_path,
                           alert: "Aucun webhook Silae configuré. Configurez-le dans les paramètres de l'organisation."
      end

      PayrollWebhookJob.perform_later(
        current_employee.organization_id,
        period.to_s
      )

      redirect_to admin_payroll_path,
                  notice: "Envoi vers Silae planifié pour #{l(period, format: '%B %Y')}."
    rescue ArgumentError
      redirect_to admin_payroll_path, alert: "Période invalide."
    end

    def export_silae
      authorize :payroll, :export_silae?
      period = params[:period].present? ? Date.strptime(params[:period], '%Y-%m') : Date.current.beginning_of_month

      if period > Date.current.end_of_month
        return redirect_to admin_payroll_path, alert: "La période ne peut pas être dans le futur."
      end

      log_silae_export(period)

      result = Exports::PayrollSilaeCsvExporter.new(current_employee, period).export
      send_data result[:content],
                filename: result[:filename],
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue ArgumentError
      redirect_to admin_payroll_path, alert: "Période invalide."
    rescue StandardError => e
      Rails.logger.error "Silae CSV export error: #{e.message}"
      redirect_to admin_payroll_path, alert: "Une erreur est survenue lors de l'export Silae. Contactez l'administrateur."
    end

    def show
      authorize :payroll, policy_class: PayrollPolicy
      org = current_employee.organization
      @employees = org.employees.active

      # ── KPI cards ──────────────────────────────────────────────────────────
      # Masse salariale brute mensuelle (gross + variable)
      @total_gross_monthly = @employees.sum('gross_salary_cents + variable_pay_cents') / 100.0

      # Coût total employeur mensuel (charges incluses)
      @total_employer_monthly = @employees.sum(
        '(gross_salary_cents + variable_pay_cents) * employer_charges_rate'
      ) / 100.0

      @headcount          = @employees.count
      @average_gross      = @headcount > 0 ? @total_gross_monthly / @headcount : 0
      @total_annual_gross = @total_gross_monthly * 12

      # ── Répartition par type de contrat ────────────────────────────────────
      @by_contract = @employees.group(:contract_type).sum('gross_salary_cents + variable_pay_cents')
                               .transform_values { |cents| cents / 100.0 }

      @headcount_by_contract = @employees.group(:contract_type).count

      # ── Répartition par département ────────────────────────────────────────
      @by_department = @employees
        .where.not(department: [nil, ''])
        .group(:department)
        .sum('gross_salary_cents + variable_pay_cents')
        .transform_values { |cents| cents / 100.0 }

      @headcount_by_department = @employees.where.not(department: [nil, '']).group(:department).count

      # ── Distribution salariale (tranches) ──────────────────────────────────
      # Build salary bands: <2k, 2-3k, 3-4k, 4-5k, >5k (monthly gross)
      @salary_bands = build_salary_bands(@employees)

      # ── Cadres vs non-cadres ────────────────────────────────────────────────
      # cadre est stocké dans settings JSONB, pas une colonne SQL
      cadre_emps       = @employees.where("settings->>'cadre' = 'true'")
      @cadre_count     = cadre_emps.count
      @non_cadre_count = @headcount - @cadre_count
      @cadre_avg_gross = @cadre_count > 0 ? cadre_emps.sum('gross_salary_cents') / @cadre_count / 100.0 : 0

      # ── Ancienneté × salaire ────────────────────────────────────────────────
      # Group by tenure bracket (< 1 an, 1-3 ans, 3-5 ans, 5+ ans)
      @by_tenure = build_tenure_salary(@employees)

      # ── Congés: coût estimé jours absents ce mois ───────────────────────────
      month_start = Date.current.beginning_of_month
      month_end   = Date.current.end_of_month
      leaves_this_month = LeaveRequest
        .where(organization_id: org.id)
        .where(status: %w[approved auto_approved])
        .where('start_date <= ? AND end_date >= ?', month_end, month_start)

      total_leave_days = leaves_this_month.sum(:days_count).to_f
      avg_daily_cost   = @average_gross / 22.0  # approx working days/month
      @leave_cost_estimate = total_leave_days * avg_daily_cost

      # ── Top 10 rémunérations (anonymisé possible) ──────────────────────────
      @top_earners = @employees.order(gross_salary_cents: :desc).limit(10)

      # ── Clôture de paie ─────────────────────────────────────────────────────
      # Last 12 months + current month for lock/unlock UI
      @payroll_periods_locked = org.payroll_periods.recent.limit(24).includes(:locked_by)
      @lockable_months = (0..11).map { |n| Date.current.beginning_of_month - n.months }.reverse

      # Last webhook push per period (keyed by 'YYYY-MM' string)
      @last_push_by_period = PaperTrail::Version
        .where(item_type: 'Organization', item_id: org.id, event: 'payroll_webhook_push')
        .order(created_at: :desc)
        .limit(48)
        .each_with_object({}) do |v, h|
          meta = JSON.parse(v.object_changes.to_s) rescue {}
          period_key = meta['period']
          h[period_key] ||= { status: meta['status'], at: v.created_at } if period_key
        end
    end

    private

    def log_silae_export(period)
      PaperTrail::Version.create!(
        item_type:       'Organization',
        item_id:         current_organization.id,
        event:           'silae_export',
        whodunnit:       current_employee.id.to_s,
        organization_id: current_organization.id,
        object_changes:  { period: period.strftime('%Y-%m'), ip: request.remote_ip }.to_json
      )
    rescue StandardError => e
      Rails.logger.error("[AuditLog] silae_export log failed: #{e.message}")
    end

    SALARY_BANDS = [
      { label: '< 2 000 €',       min: 0,      max: 200_000 },
      { label: '2 000 – 3 000 €', min: 200_000, max: 300_000 },
      { label: '3 000 – 4 000 €', min: 300_000, max: 400_000 },
      { label: '4 000 – 5 000 €', min: 400_000, max: 500_000 },
      { label: '> 5 000 €',       min: 500_000, max: Float::INFINITY }
    ].freeze

    def build_salary_bands(employees)
      # Fetch in Ruby — small enough for a company scope
      salaries = employees.pluck(:gross_salary_cents)
      SALARY_BANDS.map do |band|
        count = salaries.count { |c| c >= band[:min] && c < band[:max] }
        { label: band[:label], count: count }
      end
    end

    TENURE_BRACKETS = [
      { label: '< 1 an',   min: 0,  max: 12 },
      { label: '1 – 3 ans', min: 12, max: 36 },
      { label: '3 – 5 ans', min: 36, max: 60 },
      { label: '5+ ans',    min: 60, max: Float::INFINITY }
    ].freeze

    def build_tenure_salary(employees)
      data = employees.pluck(:start_date, :gross_salary_cents)
      today = Date.current

      TENURE_BRACKETS.map do |bracket|
        group = data.select do |start_date, _|
          months = ((today - start_date) / 30).to_i
          months >= bracket[:min] && months < bracket[:max]
        end
        total_cents = group.sum { |_, cents| cents }
        count       = group.size
        avg         = count > 0 ? total_cents / count / 100.0 : 0
        { label: bracket[:label], count: count, avg_gross: avg }
      end
    end
  end
end
