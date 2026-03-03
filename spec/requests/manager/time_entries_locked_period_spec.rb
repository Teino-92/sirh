# frozen_string_literal: true

require 'rails_helper'

# Covers M2: Manager::TimeEntriesController must surface a clean flash alert
# (not raise) when validate!/reject! hits the period_not_locked guard.

RSpec.describe 'Manager::TimeEntries locked-period guard', type: :request do
  let(:org)      { create(:organization) }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:member)   { create(:employee, organization: org, role: 'employee', manager: manager) }

  # A completed, unvalidated entry in January 2026 (which will be locked)
  let(:locked_date) { Time.zone.local(2026, 1, 15, 9, 0, 0) }
  let!(:entry) do
    ActsAsTenant.with_tenant(org) do
      create(:time_entry,
             employee:         member,
             organization:     org,
             clock_in:         locked_date,
             clock_out:        locked_date + 8.hours,
             duration_minutes: 480)
    end
  end

  before do
    ActsAsTenant.current_tenant = org
    # Lock January 2026
    create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 1))
    sign_in manager
  end

  after { ActsAsTenant.current_tenant = nil }

  # ── validate_entry ────────────────────────────────────────────────────────

  describe 'POST validate_entry on a locked period' do
    it 'redirects with a flash alert instead of raising' do
      post validate_entry_manager_team_member_time_entry_path(member, entry)
      expect(response).to be_redirect
      follow_redirect!
      expect(response.body).to include('clôturée')
    end

    it 'does not mark the entry as validated' do
      post validate_entry_manager_team_member_time_entry_path(member, entry)
      expect(entry.reload.validated_at).to be_nil
    end
  end

  # ── reject_entry ──────────────────────────────────────────────────────────

  describe 'POST reject_entry on a locked period' do
    it 'redirects with a flash alert instead of raising' do
      post reject_entry_manager_team_member_time_entry_path(member, entry),
           params: { rejection_reason: 'test' }
      expect(response).to be_redirect
      follow_redirect!
      expect(response.body).to include('clôturée')
    end

    it 'does not mark the entry as rejected' do
      post reject_entry_manager_team_member_time_entry_path(member, entry),
           params: { rejection_reason: 'test' }
      expect(entry.reload.rejected_at).to be_nil
    end
  end

  # ── validate_week ─────────────────────────────────────────────────────────

  describe 'POST validate_week when all entries are in a locked period' do
    it 'redirects with an alert mentioning the locked period' do
      post validate_week_manager_team_member_time_entries_path(member),
           params: { week_start: '2026-01-12' }
      expect(response).to be_redirect
      follow_redirect!
      expect(response.body).to include('clôturée')
    end

    it 'does not validate any entry' do
      post validate_week_manager_team_member_time_entries_path(member),
           params: { week_start: '2026-01-12' }
      expect(entry.reload.validated_at).to be_nil
    end
  end
end
