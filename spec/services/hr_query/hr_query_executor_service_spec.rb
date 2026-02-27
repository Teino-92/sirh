# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HrQuery::HrQueryExecutorService, type: :service do
  # ─── Tenant setup ───────────────────────────────────────────────────────────
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:hr)    { create(:employee, organization: org_a, role: 'hr') }

  # Set the tenant before each test so acts_as_tenant scoping is active
  before { ActsAsTenant.current_tenant = org_a }
  after  { ActsAsTenant.current_tenant = nil }

  # ─── Helpers ────────────────────────────────────────────────────────────────

  def build_filters(employee: {}, leave: {}, evaluation: {}, onboarding: {}, output: {})
    {
      "version"    => "1",
      "employee"   => { "active_only" => true }.merge(employee),
      "leave"      => leave,
      "evaluation" => evaluation,
      "onboarding" => onboarding,
      "output"     => { "columns" => ["name", "department"] }.merge(output)
    }
  end

  def run(filters)
    described_class.new(filters, hr).call
  end

  def names(rows)
    rows.map { |r| r["name"] }
  end

  # ─── Department filter ───────────────────────────────────────────────────────

  describe 'employee.department filter' do
    let!(:sales_emp)  { create(:employee, organization: org_a, department: 'Ventes') }
    let!(:it_emp)     { create(:employee, organization: org_a, department: 'IT') }

    it 'returns only employees in the specified department' do
      result = run(build_filters(employee: { "department" => "Ventes" }))
      expect(names(result)).to include(sales_emp.full_name)
      expect(names(result)).not_to include(it_emp.full_name)
    end
  end

  # ─── Contract type filter ────────────────────────────────────────────────────

  describe 'employee.contract_type filter' do
    let!(:cdi_emp) { create(:employee, organization: org_a, contract_type: 'CDI') }
    let!(:cdd_emp) { create(:employee, :cdd, organization: org_a) }

    it 'returns only employees with matching contract type' do
      result = run(build_filters(employee: { "contract_type" => "CDD" }))
      expect(names(result)).to include(cdd_emp.full_name)
      expect(names(result)).not_to include(cdi_emp.full_name)
    end
  end

  # ─── Leave days filter ───────────────────────────────────────────────────────

  describe 'leave.days_used_min filter' do
    let!(:emp_lots)  { create(:employee, organization: org_a) }
    let!(:emp_few)   { create(:employee, organization: org_a) }

    before do
      # emp_lots: 12 approved RTT days this year
      create(:leave_request,
             employee: emp_lots, organization: org_a,
             leave_type: 'RTT', days_count: 12.0,
             status: 'approved',
             start_date: Date.current.beginning_of_year + 10,
             end_date:   Date.current.beginning_of_year + 21)

      # emp_few: 3 approved RTT days this year
      create(:leave_request,
             employee: emp_few, organization: org_a,
             leave_type: 'RTT', days_count: 3.0,
             status: 'approved',
             start_date: Date.current.beginning_of_year + 5,
             end_date:   Date.current.beginning_of_year + 7)
    end

    it 'returns only employees with >= 10 RTT days' do
      filters = build_filters(
        leave: {
          "leave_type"    => "RTT",
          "days_used_min" => 10.0,
          "period_year"   => Date.current.year,
          "status"        => "approved"
        },
        output: { "columns" => ["name", "leave_days_used"] }
      )
      result = run(filters)
      expect(names(result)).to include(emp_lots.full_name)
      expect(names(result)).not_to include(emp_few.full_name)
    end
  end

  # ─── Evaluation score filter ─────────────────────────────────────────────────

  describe 'evaluation.score_min filter' do
    let!(:mgr)        { create(:employee, organization: org_a, role: 'manager') }
    let!(:high_scorer) { create(:employee, organization: org_a) }
    let!(:low_scorer)  { create(:employee, organization: org_a) }

    before do
      create(:evaluation, :completed,
             employee: high_scorer, manager: mgr,
             organization: org_a, score: 4,
             period_start: Date.current.beginning_of_year,
             period_end:   Date.current.end_of_year)

      create(:evaluation, :completed,
             employee: low_scorer, manager: mgr,
             organization: org_a, score: 2,
             period_start: Date.current.beginning_of_year,
             period_end:   Date.current.end_of_year)
    end

    it 'returns only employees with score >= 4' do
      filters = build_filters(
        evaluation: {
          "score_min"   => 4,
          "period_year" => Date.current.year,
          "status"      => "completed"
        },
        output: { "columns" => ["name", "evaluation_score"] }
      )
      result = run(filters)
      expect(names(result)).to include(high_scorer.full_name)
      expect(names(result)).not_to include(low_scorer.full_name)
    end
  end

  # ─── Tenant isolation ────────────────────────────────────────────────────────

  describe 'multi-tenant isolation' do
    let!(:emp_a) { create(:employee, organization: org_a, department: 'Ventes') }

    # emp_b belongs to a completely different organization
    let!(:emp_b) do
      ActsAsTenant.with_tenant(org_b) do
        create(:employee, organization: org_b, department: 'Ventes')
      end
    end

    it 'never returns employees from a different organization' do
      # Tenant is set to org_a — emp_b must never appear
      result = run(build_filters(employee: { "department" => "Ventes" }))
      result_names = names(result)
      expect(result_names).to include(emp_a.full_name)
      expect(result_names).not_to include(emp_b.full_name)
    end
  end

  # ─── Salary gating ───────────────────────────────────────────────────────────

  describe 'salary column visibility' do
    # Use a known department so we can isolate just this employee in results
    let!(:emp) do
      create(:employee, organization: org_a,
             department: 'FinanceSalaryTest',
             gross_salary_cents: 350_000,
             employer_charges_rate: 1.45)
    end

    let(:salary_filters) do
      build_filters(
        employee: { "department" => "FinanceSalaryTest" },
        output: { "columns" => ["name", "salary"], "include_salary" => true }
      )
    end

    context 'when requester is HR' do
      it 'includes salary value for the employee' do
        result = described_class.new(salary_filters, hr).call
        # Only emp should be returned (department filter)
        expect(result.size).to eq(1)
        expect(result.first["salary"]).to eq("3500.0 €")
      end
    end

    context 'when requester is a plain manager' do
      let(:manager) { create(:employee, organization: org_a, role: 'manager') }

      it 'masks salary with a dash for all results' do
        result = described_class.new(salary_filters, manager).call
        salary_values = result.map { |r| r["salary"] }
        expect(salary_values).to all(eq("—"))
      end
    end
  end

  # ─── MAX_RESULTS cap ────────────────────────────────────────────────────────

  describe 'MAX_RESULTS' do
    it 'is set to 500' do
      expect(described_class::MAX_RESULTS).to eq(500)
    end
  end

  # ─── Empty filters ───────────────────────────────────────────────────────────

  describe 'with empty filters' do
    let!(:emp) { create(:employee, organization: org_a) }

    it 'returns active employees' do
      result = run(build_filters)
      expect(result).not_to be_empty
    end
  end

  # ─── inactive employees ──────────────────────────────────────────────────────

  describe 'active_only filter' do
    let!(:active_emp)   { create(:employee, organization: org_a, settings: { 'active' => true }) }
    let!(:inactive_emp) { create(:employee, organization: org_a, settings: { 'active' => false }) }

    it 'excludes inactive employees by default' do
      result = run(build_filters)
      result_names = names(result)
      expect(result_names).to include(active_emp.full_name)
      expect(result_names).not_to include(inactive_emp.full_name)
    end

    it 'includes inactive employees when active_only is false' do
      result = run(build_filters(employee: { "active_only" => false }))
      result_names = names(result)
      expect(result_names).to include(active_emp.full_name)
      expect(result_names).to include(inactive_emp.full_name)
    end
  end
end
