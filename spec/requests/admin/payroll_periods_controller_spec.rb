# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::PayrollPeriods', type: :request do
  let(:org)      { create(:organization) }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  # ── POST /admin/payroll/payroll_periods (lock) ────────────────────────────

  describe 'POST /admin/payroll/payroll_periods' do
    let(:valid_period) { '2026-01' }

    context 'when unauthenticated' do
      it 'redirects to sign in' do
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        expect(response).to redirect_to(new_employee_session_path)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'redirects with authorization alert' do
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        expect(response).to be_redirect
        expect(flash[:alert]).to include('autorisé')
      end
    end

    context 'when authenticated as plain employee' do
      before { sign_in employee }

      it 'redirects with authorization alert' do
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        expect(response).to be_redirect
        expect(flash[:alert]).to include('autorisé')
      end
    end

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'creates a payroll_period and redirects with notice' do
        expect {
          post admin_payroll_payroll_periods_path, params: { period: valid_period }
        }.to change(PayrollPeriod, :count).by(1)
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('clôturée').or include('janvier').or include('2026')
      end

      it 'locks the correct period' do
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        pp = PayrollPeriod.last
        expect(pp.period).to eq(Date.new(2026, 1, 1))
        expect(pp.locked_by).to eq(hr)
      end

      it 'redirects with alert for duplicate period' do
        create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 1))
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        # Flash should contain an error message (the uniqueness validation message)
        expect(response.body).to include('déjà').or include('clôturée')
      end

      it 'redirects with alert for a malformed period' do
        post admin_payroll_payroll_periods_path, params: { period: 'not-a-date' }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('invalide')
      end

      it 'does not lock a period for another organization' do
        org_b = create(:organization)
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        expect(PayrollPeriod.where(organization_id: org_b.id).count).to eq(0)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'permits access' do
        post admin_payroll_payroll_periods_path, params: { period: valid_period }
        expect(response).to redirect_to(admin_payroll_path)
        expect(PayrollPeriod.count).to eq(1)
      end
    end
  end

  # ── DELETE /admin/payroll/payroll_periods/:id (unlock) ────────────────────

  describe 'DELETE /admin/payroll/payroll_periods/:id' do
    let!(:locked_period) do
      create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 1))
    end

    context 'when unauthenticated' do
      it 'redirects to sign in' do
        delete admin_payroll_payroll_period_path(locked_period)
        expect(response).to redirect_to(new_employee_session_path)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'redirects with authorization alert' do
        delete admin_payroll_payroll_period_path(locked_period)
        expect(response).to be_redirect
        expect(flash[:alert]).to include('autorisé')
      end
    end

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'destroys the payroll_period and redirects with notice' do
        expect {
          delete admin_payroll_payroll_period_path(locked_period)
        }.to change(PayrollPeriod, :count).by(-1)
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('rouverte').or include('janvier').or include('2026')
      end

      it 'cannot unlock a period from another organization (tenant isolation)' do
        org_b    = create(:organization)
        hr_b     = ActsAsTenant.with_tenant(org_b) { create(:employee, organization: org_b, role: 'hr') }
        period_b = ActsAsTenant.with_tenant(org_b) do
          create(:payroll_period, organization: org_b, locked_by: hr_b, period: Date.new(2026, 1, 1))
        end
        # acts_as_tenant scopes the find to current org — period_b not found → RecordNotFound → 404
        delete admin_payroll_payroll_period_path(period_b)
        expect(response).to have_http_status(:not_found)
        # The period in org_b must remain locked
        expect(ActsAsTenant.with_tenant(org_b) { PayrollPeriod.exists?(period_b.id) }).to be true
      end
    end
  end
end
