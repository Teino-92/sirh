# frozen_string_literal: true

module Admin
  class PayrollController < BaseController
    def show
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
      cadre_ids = @employees.select { |e| e.cadre? }.map(&:id)
      @cadre_count     = cadre_ids.size
      @non_cadre_count = @headcount - @cadre_count

      cadre_emps = @employees.where(id: cadre_ids)
      @cadre_avg_gross = cadre_emps.any? ? cadre_emps.sum('gross_salary_cents') / cadre_emps.count / 100.0 : 0

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
    end

    private

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
