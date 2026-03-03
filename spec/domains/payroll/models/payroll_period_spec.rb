# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PayrollPeriod, type: :model do
  let(:org) { create(:organization) }
  let(:hr)  { create(:employee, organization: org, role: 'hr') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  # ── Validations ───────────────────────────────────────────────────────────

  describe 'validations' do
    it 'is valid with all required attributes' do
      pp = build(:payroll_period, organization: org, locked_by: hr)
      expect(pp).to be_valid
    end

    it 'requires period' do
      pp = build(:payroll_period, organization: org, locked_by: hr, period: nil)
      expect(pp).not_to be_valid
      expect(pp.errors[:period]).to be_present
    end

    it 'requires locked_at' do
      pp = build(:payroll_period, organization: org, locked_by: hr, locked_at: nil)
      expect(pp).not_to be_valid
    end

    it 'requires locked_by' do
      pp = build(:payroll_period, organization: org, locked_by: nil)
      expect(pp).not_to be_valid
    end

    it 'enforces uniqueness of period within the same organization' do
      create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 1))
      dup = build(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 15))
      expect(dup).not_to be_valid
      expect(dup.errors[:period]).to be_present
    end

    it 'allows the same period for different organizations' do
      org_b = create(:organization)
      hr_b  = ActsAsTenant.with_tenant(org_b) { create(:employee, organization: org_b, role: 'hr') }
      create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 1))
      ActsAsTenant.with_tenant(org_b) do
        pp_b = build(:payroll_period, organization: org_b, locked_by: hr_b, period: Date.new(2026, 1, 1))
        expect(pp_b).to be_valid
      end
    end
  end

  # ── normalize_period ─────────────────────────────────────────────────────

  describe 'normalize_period' do
    it 'normalizes mid-month date to beginning_of_month' do
      pp = create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 1, 15))
      expect(pp.period).to eq(Date.new(2026, 1, 1))
    end

    it 'leaves beginning_of_month unchanged' do
      pp = create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 2, 1))
      expect(pp.period).to eq(Date.new(2026, 2, 1))
    end
  end

  # ── .locked? ─────────────────────────────────────────────────────────────

  describe '.locked?' do
    let(:locked_month) { Date.new(2026, 1, 1) }

    before do
      create(:payroll_period, organization: org, locked_by: hr, period: locked_month)
    end

    it 'returns true for a date in a locked month' do
      expect(PayrollPeriod.locked?(org.id, Date.new(2026, 1, 15))).to be true
    end

    it 'returns true for the first day of a locked month' do
      expect(PayrollPeriod.locked?(org.id, locked_month)).to be true
    end

    it 'returns false for a date in an unlocked month' do
      expect(PayrollPeriod.locked?(org.id, Date.new(2026, 2, 1))).to be false
    end

    it 'returns false for a different organization' do
      org_b = create(:organization)
      expect(PayrollPeriod.locked?(org_b.id, Date.new(2026, 1, 15))).to be false
    end
  end

  # ── TimeEntry guard ───────────────────────────────────────────────────────

  describe 'TimeEntry guard' do
    let(:employee) { create(:employee, organization: org) }
    let(:locked_month) { Date.new(2026, 1, 1) }

    before do
      create(:payroll_period, organization: org, locked_by: hr, period: locked_month)
    end

    it 'rejects a new TimeEntry whose clock_in falls in a locked period' do
      entry = build(:time_entry,
                    employee:         employee,
                    organization:     org,
                    clock_in:         Time.new(2026, 1, 15, 9, 0, 0),
                    clock_out:        Time.new(2026, 1, 15, 17, 0, 0),
                    duration_minutes: 480)
      expect(entry).not_to be_valid
      expect(entry.errors[:base].join).to include('clôturée')
    end

    it 'allows a TimeEntry in an unlocked period' do
      entry = build(:time_entry,
                    employee:         employee,
                    organization:     org,
                    clock_in:         Time.new(2026, 2, 1, 9, 0, 0),
                    clock_out:        Time.new(2026, 2, 1, 17, 0, 0),
                    duration_minutes: 480)
      expect(entry.errors[:base]).to be_empty
    end
  end

  # ── LeaveRequest guard ────────────────────────────────────────────────────

  describe 'LeaveRequest guard' do
    let(:employee) { create(:employee, organization: org) }
    let(:locked_month) { Date.new(2026, 1, 1) }

    before do
      create(:payroll_period, organization: org, locked_by: hr, period: locked_month)
      create(:leave_balance, employee: employee, organization: org,
             leave_type: 'CP', balance: 20, used_this_year: 0)
    end

    it 'rejects a LeaveRequest whose start_date falls in a locked period' do
      lr = build(:leave_request,
                 employee:     employee,
                 organization: org,
                 leave_type:   'CP',
                 status:       'pending',
                 start_date:   Date.new(2026, 1, 10),
                 end_date:     Date.new(2026, 1, 12),
                 days_count:   3)
      expect(lr).not_to be_valid
      expect(lr.errors[:base].join).to include('clôturée')
    end

    it 'allows a LeaveRequest in an unlocked period' do
      lr = build(:leave_request,
                 employee:     employee,
                 organization: org,
                 leave_type:   'CP',
                 status:       'pending',
                 start_date:   Date.new(2026, 2, 2),
                 end_date:     Date.new(2026, 2, 4),
                 days_count:   3)
      # Only checking period_not_locked — other validations may fire
      expect(lr.errors[:base].map { |e| e.include?('clôturée') }).to all(be false)
    end

    it 'raises RecordInvalid when auto_approve! is called on a locked period' do
      # Persist first without lock, then lock the period and call auto_approve!
      lr = ActsAsTenant.without_tenant do
        create(:leave_request,
               employee:     employee,
               organization: org,
               leave_type:   'CP',
               status:       'pending',
               start_date:   Date.new(2026, 2, 5),
               end_date:     Date.new(2026, 2, 7),
               days_count:   3)
      end
      # Now lock February
      create(:payroll_period, organization: org, locked_by: hr, period: Date.new(2026, 2, 1))
      expect { lr.auto_approve! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
