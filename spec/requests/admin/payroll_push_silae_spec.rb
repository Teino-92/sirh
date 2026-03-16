# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Payroll#push_silae', type: :request do
  let(:org)      { create(:organization) }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  let(:locked_period) { Date.new(2026, 1, 1) }

  before do
    # Stub DNS so the SSRF validator accepts silae.example.com in test
    allow(Resolv).to receive(:getaddress).with('silae.example.com').and_return('1.2.3.4')
    ActsAsTenant.current_tenant = org
    org.settings['payroll_webhook_url'] = 'https://silae.example.com/webhook'
    org.save!
    create(:payroll_period, organization: org, locked_by: hr, period: locked_period)
  end

  after { ActsAsTenant.current_tenant = nil }

  describe 'POST /admin/payroll/push_silae' do
    context 'when unauthenticated' do
      it 'redirects to sign in' do
        post push_silae_admin_payroll_path, params: { period: '2026-01' }
        expect(response).to redirect_to(new_employee_session_path)
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'denies access with authorization alert' do
        post push_silae_admin_payroll_path, params: { period: '2026-01' }
        expect(response).to be_redirect
        expect(flash[:alert]).to include('autorisé')
      end
    end

    context 'when authenticated as plain employee' do
      before { sign_in employee }

      it 'denies access' do
        post push_silae_admin_payroll_path, params: { period: '2026-01' }
        expect(response).to be_redirect
        expect(flash[:alert]).to include('autorisé')
      end
    end

    context 'when authenticated as HR' do
      before { sign_in hr }

      it 'enqueues PayrollWebhookJob and redirects with notice' do
        expect {
          post push_silae_admin_payroll_path, params: { period: '2026-01' }
        }.to have_enqueued_job(PayrollWebhookJob)
          .with(org.id, locked_period.to_s)
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('planifié').or include('Silae')
      end

      it 'rejects an unlocked period with an alert' do
        post push_silae_admin_payroll_path, params: { period: '2026-02' }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('clôturée')
        expect(PayrollWebhookJob).not_to have_been_enqueued
      end

      it 'rejects when no webhook URL is configured' do
        org.settings.delete('payroll_webhook_url')
        org.save!
        post push_silae_admin_payroll_path, params: { period: '2026-01' }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('webhook')
        expect(PayrollWebhookJob).not_to have_been_enqueued
      end

      it 'rejects a malformed period with an alert' do
        post push_silae_admin_payroll_path, params: { period: 'bad-date' }
        expect(response).to redirect_to(admin_payroll_path)
        follow_redirect!
        expect(response.body).to include('invalide')
      end

      it 'does not enqueue a job for another organization' do
        org_b = create(:organization)
        expect {
          post push_silae_admin_payroll_path, params: { period: '2026-01' }
        }.not_to have_enqueued_job(PayrollWebhookJob).with(org_b.id, anything)
      end
    end

    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'permits access and enqueues the job' do
        expect {
          post push_silae_admin_payroll_path, params: { period: '2026-01' }
        }.to have_enqueued_job(PayrollWebhookJob)
        expect(response).to redirect_to(admin_payroll_path)
      end
    end
  end
end
