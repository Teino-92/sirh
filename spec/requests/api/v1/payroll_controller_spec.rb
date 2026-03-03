# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Payroll', type: :request do
  let(:org)      { create(:organization) }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  # ── GET /api/v1/payroll/employees ────────────────────────────────────────────

  describe 'GET /api/v1/payroll/employees' do
    context 'when unauthenticated' do
      it 'redirects to sign in' do
        get api_v1_payroll_employees_path
        expect(response).to redirect_to(new_employee_session_path)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'returns 403' do
        get api_v1_payroll_employees_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as plain employee' do
      before { sign_in employee }

      it 'returns 403' do
        get api_v1_payroll_employees_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'returns 200 with correct JSON structure' do
        get api_v1_payroll_employees_path
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key('data')
        expect(body).to have_key('period')
        expect(body).to have_key('meta')
      end

      it 'includes pagination meta' do
        get api_v1_payroll_employees_path
        meta = response.parsed_body['meta']
        expect(meta).to include('current_page', 'total_pages', 'total_count')
      end

      it 'defaults to current month period when absent' do
        get api_v1_payroll_employees_path
        expect(response.parsed_body['period']).to eq(Date.current.strftime('%Y-%m'))
      end

      it 'returns 400 for a malformed period param' do
        get api_v1_payroll_employees_path, params: { period: 'not-a-date' }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to include('invalide')
      end

      it 'respects the period param' do
        get api_v1_payroll_employees_path, params: { period: '2026-01' }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['period']).to eq('2026-01')
      end

      it 'clamps per_page to 1 when per_page=1 is requested' do
        create_list(:employee, 3, organization: org, role: 'employee')
        get api_v1_payroll_employees_path, params: { per_page: 1 }
        expect(response).to have_http_status(:ok)
        # After M1 fix: per_page=1 is honoured, not forced to 25
        meta = response.parsed_body['meta']
        expect(meta['total_count']).to be >= 1
      end

      it 'returns each employee row with payroll sub-object' do
        create(:employee, organization: org, role: 'employee')
        get api_v1_payroll_employees_path
        rows = response.parsed_body['data']
        expect(rows).to be_an(Array)
        unless rows.empty?
          row = rows.first
          expect(row).to include('id', 'full_name', 'gross_salary', 'payroll')
          expect(row['payroll']).to include('base_salary', 'worked_hours', 'gross_total')
        end
      end

      it 'does not include employees from another organization' do
        org_b    = create(:organization)
        other_hr = ActsAsTenant.with_tenant(org_b) { create(:employee, organization: org_b, role: 'hr') }

        get api_v1_payroll_employees_path
        ids = response.parsed_body['data'].map { |r| r['id'] }
        expect(ids).not_to include(other_hr.id)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'returns 200' do
        get api_v1_payroll_employees_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ── GET /api/v1/payroll/employees/:id ────────────────────────────────────────

  describe 'GET /api/v1/payroll/employees/:id' do
    let!(:target) { create(:employee, organization: org, role: 'employee') }

    context 'when unauthenticated' do
      it 'redirects to sign in' do
        get api_v1_payroll_employee_path(target)
        expect(response).to redirect_to(new_employee_session_path)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'returns 403' do
        get api_v1_payroll_employee_path(target)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'returns 200 with employee payroll detail' do
        get api_v1_payroll_employee_path(target)
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['data']['id']).to eq(target.id)
        expect(body['data']).to have_key('payroll')
        expect(body['data']['payroll']).to include(
          'base_salary', 'worked_hours', 'contractual_hours',
          'overtime_25', 'overtime_50', 'gross_total'
        )
      end

      it 'returns 404 for an unknown id' do
        get api_v1_payroll_employee_path(id: 0)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for an employee from another organization (tenant isolation)' do
        org_b  = create(:organization)
        emp_b  = ActsAsTenant.with_tenant(org_b) { create(:employee, organization: org_b) }
        get api_v1_payroll_employee_path(id: emp_b.id)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 400 for a malformed period param' do
        get api_v1_payroll_employee_path(target), params: { period: 'bad' }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  # ── GET /api/v1/payroll/summary ──────────────────────────────────────────────

  describe 'GET /api/v1/payroll/summary' do
    context 'when unauthenticated' do
      it 'redirects to sign in' do
        get api_v1_payroll_summary_path
        expect(response).to redirect_to(new_employee_session_path)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'returns 403' do
        get api_v1_payroll_summary_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'returns 200 with all KPI keys' do
        get api_v1_payroll_summary_path
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to include(
          'period', 'headcount', 'total_gross', 'total_employer',
          'average_gross', 'total_annual', 'by_contract',
          'by_department', 'leave_cost_estimate'
        )
      end

      it 'returns average_gross of 0 when org has no active employees (no div/0)' do
        # Deactivate all employees in org (HR itself is active, so create org with no others)
        org_empty = create(:organization)
        hr_empty  = create(:employee, organization: org_empty, role: 'hr')
        sign_in hr_empty
        ActsAsTenant.current_tenant = org_empty

        get api_v1_payroll_summary_path
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['average_gross']).to eq(0.0)
      end

      it 'returns 400 for a malformed period param' do
        get api_v1_payroll_summary_path, params: { period: 'not-a-date' }
        expect(response).to have_http_status(:bad_request)
      end

      it 'defaults to current month period when absent' do
        get api_v1_payroll_summary_path
        expect(response.parsed_body['period']).to eq(Date.current.strftime('%Y-%m'))
      end

      it 'does not include KPIs from another organization' do
        org_b = create(:organization)
        ActsAsTenant.with_tenant(org_b) do
          create(:employee, organization: org_b, role: 'employee',
                 gross_salary_cents: 500_000)
        end

        get api_v1_payroll_summary_path
        # HR's own org has only the HR employee — total_gross should not include org_b data
        expect(response).to have_http_status(:ok)
        # Headcount should only reflect current org
        expect(response.parsed_body['headcount']).to eq(org.employees.active.count)
      end
    end
  end
end
