# frozen_string_literal: true

require 'rails_helper'

# Covers M3: LeaveRequestsController must surface a clean flash alert
# (not raise) when approve!/reject!/cancel hits the period_not_locked guard.
# Covers R1: auto_approve! on a locked period (race-window scenario) must not 500.

RSpec.describe 'LeaveRequests locked-period guard', type: :request do
  let(:org)     { create(:organization) }
  let(:hr)      { create(:employee, organization: org, role: 'hr') }
  let(:manager) { create(:employee, organization: org, role: 'manager') }
  let(:member)  { create(:employee, organization: org, role: 'employee', manager: manager) }

  # A pending leave request in January 2026 (which will be locked)
  let!(:leave_request) do
    ActsAsTenant.with_tenant(org) do
      create(:leave_balance, employee: member, organization: org,
             leave_type: 'CP', balance: 20, used_this_year: 0)
      create(:leave_request,
             employee:     member,
             organization: org,
             leave_type:   'CP',
             status:       'pending',
             start_date:   Date.new(2026, 1, 10),
             end_date:     Date.new(2026, 1, 12),
             days_count:   3)
    end
  end

  before do
    ActsAsTenant.current_tenant = org
    # Lock January 2026
    create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 1))
  end

  after { ActsAsTenant.current_tenant = nil }

  # ── approve ───────────────────────────────────────────────────────────────

  describe 'POST approve on a locked period' do
    before { sign_in manager }

    it 'redirects with a flash alert instead of raising' do
      post approve_leave_request_path(leave_request)
      expect(response).to be_redirect
      follow_redirect!
      expect(response.body).to include('clôturée')
    end

    it 'does not change the leave request status' do
      post approve_leave_request_path(leave_request)
      expect(leave_request.reload.status).to eq('pending')
    end
  end

  # ── reject ────────────────────────────────────────────────────────────────

  describe 'POST reject on a locked period' do
    before { sign_in manager }

    it 'redirects with a flash alert instead of raising' do
      post reject_leave_request_path(leave_request),
           params: { rejection_reason: 'coverage' }
      expect(response).to be_redirect
      follow_redirect!
      expect(response.body).to include('clôturée')
    end

    it 'does not change the leave request status' do
      post reject_leave_request_path(leave_request),
           params: { rejection_reason: 'coverage' }
      expect(leave_request.reload.status).to eq('pending')
    end
  end

  # ── cancel ────────────────────────────────────────────────────────────────

  describe 'POST cancel on a locked period' do
    before { sign_in member }

    it 'redirects with a flash alert instead of raising' do
      post cancel_leave_request_path(leave_request)
      expect(response).to be_redirect
      follow_redirect!
      expect(response.body).to include('clôturée')
    end

    it 'does not change the leave request status' do
      post cancel_leave_request_path(leave_request)
      expect(leave_request.reload.status).to eq('pending')
    end
  end

  # ── auto_approve! race-window (R1) ────────────────────────────────────────
  #
  # Simulates: period is unlocked at save time, then locked before auto_approve!
  # fires. We stub auto_approve! to raise RecordInvalid on the specific instance.

  describe 'POST create when auto_approve! raises RecordInvalid (race window)' do
    let(:employee_for_create) { create(:employee, organization: org, role: 'employee', manager: manager) }

    before do
      ActsAsTenant.current_tenant = org
      create(:leave_balance, employee: employee_for_create, organization: org,
             leave_type: 'RTT', balance: 10, used_this_year: 0)
      sign_in employee_for_create
    end

    it 'redirects with a pending notice instead of raising' do
      # Stub: save succeeds (period is open at that moment), but auto_approve! raises
      allow_any_instance_of(LeaveRequest).to receive(:auto_approve!)
        .and_raise(ActiveRecord::RecordInvalid.new(LeaveRequest.new))
      allow_any_instance_of(LeaveManagement::Services::LeavePolicyEngine)
        .to receive(:can_auto_approve?).and_return(true)

      post leave_requests_path, params: {
        leave_request: {
          leave_type:  'RTT',
          start_date:  3.months.from_now.to_date.to_s,
          end_date:    3.months.from_now.to_date.to_s,
          start_half_day: false,
          end_half_day:   false,
          reason:      'test'
        }
      }

      expect(response).to be_redirect
      follow_redirect!
      # Must not 500 — should show pending notice
      expect(response.body).to include('approbation').or include('créée')
    end
  end
end
