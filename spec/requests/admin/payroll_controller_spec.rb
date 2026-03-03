# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Payroll', type: :request do
  let(:org)      { create(:organization) }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  # ── export_silae ─────────────────────────────────────────────────────────────

  describe 'GET /admin/payroll/export_silae' do
    let(:valid_period) { '2026-01' }  # past month — always valid

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'returns 200 and a CSV attachment for a valid past period' do
        get export_silae_admin_payroll_path, params: { period: valid_period }
        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('.csv')
      end

      it 'filename includes the requested period' do
        get export_silae_admin_payroll_path, params: { period: valid_period }
        expect(response.headers['Content-Disposition']).to include('silae_2026-01')
      end

      it 'defaults to current month when period param is absent' do
        get export_silae_admin_payroll_path
        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to include('text/csv')
      end

      it 'redirects with alert for a future period' do
        future = (Date.current + 1.month).strftime('%Y-%m')
        get export_silae_admin_payroll_path, params: { period: future }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('futur')
      end

      it 'redirects with alert for a malformed period param' do
        get export_silae_admin_payroll_path, params: { period: 'not-a-date' }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('invalide')
      end

      it 'does NOT expose exception messages in the response body' do
        # Force an error by passing an unparseable value and ensure no Ruby error leaks
        get export_silae_admin_payroll_path, params: { period: '9999-99' }
        # Either redirects cleanly or returns CSV — must not contain backtrace/error class
        expect(response.body).not_to include('ArgumentError')
        expect(response.body).not_to include('rescue')
        expect(response.body).not_to include('/app/') # no file paths
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'permits access' do
        get export_silae_admin_payroll_path, params: { period: valid_period }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'redirects with an authorization alert' do
        get export_silae_admin_payroll_path, params: { period: valid_period }
        expect(response).to be_redirect
        follow_redirect!
        expect(response.body).to include("autorisé")
      end
    end

    context 'when authenticated as plain employee' do
      before { sign_in employee }

      it 'redirects with an authorization alert' do
        get export_silae_admin_payroll_path, params: { period: valid_period }
        expect(response).to be_redirect
        follow_redirect!
        expect(response.body).to include("autorisé")
      end
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        get export_silae_admin_payroll_path, params: { period: valid_period }
        expect(response).to redirect_to(new_employee_session_path)
      end
    end
  end

end
