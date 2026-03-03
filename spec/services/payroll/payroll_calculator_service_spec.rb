# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payroll::PayrollCalculatorService, type: :service do
  let(:org)      { create(:organization) }
  let(:schedule) { create(:work_schedule, :full_time_35h, organization: org, employee: employee) }
  let(:employee) do
    create(:employee,
           organization:          org,
           gross_salary_cents:    300_000,   # 3 000 €/month
           variable_pay_cents:    0,
           employer_charges_rate: 1.45,
           part_time_rate:        nil,
           start_date:            2.years.ago.to_date)
  end

  # Fixed period: February 2026 (28 days, 20 business days)
  let(:period) { Date.new(2026, 2, 1) }

  before do
    ActsAsTenant.current_tenant = org
    schedule  # ensure work_schedule is created and associated
  end

  after { ActsAsTenant.current_tenant = nil }

  def call(preloaded_te: nil, preloaded_lr: nil)
    described_class.new(
      employee, period,
      preloaded_time_entries:   preloaded_te,
      preloaded_leave_requests: preloaded_lr
    ).call
  end

  def make_entry(duration_minutes:, break_duration_minutes: 0)
    build_stubbed(:time_entry,
                  employee:               employee,
                  organization:           org,
                  duration_minutes:       duration_minutes,
                  break_duration_minutes: break_duration_minutes,
                  validated_at:           1.hour.ago)
  end

  def make_leave(leave_type:, days_count:, status: 'approved')
    build_stubbed(:leave_request,
                  employee:     employee,
                  organization: org,
                  leave_type:   leave_type,
                  days_count:   days_count,
                  status:       status,
                  start_date:   period,
                  end_date:     period.end_of_month)
  end

  # ── Zero salary ─────────────────────────────────────────────────────────────

  describe 'zero salary employee' do
    before { employee.update!(gross_salary_cents: 0) }

    it 'returns zero gross_total without raising' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:gross_total]).to eq(0.0)
      expect(result[:base_salary]).to eq(0.0)
    end
  end

  # ── No time entries, no leave ────────────────────────────────────────────────

  describe 'no time entries, no leave' do
    it 'returns base_salary equal to gross_salary' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:base_salary]).to eq(3000.0)
    end

    it 'returns zero worked_hours' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:worked_hours]).to eq(0.0)
    end

    it 'returns zero overtime' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:overtime_25]).to eq(0.0)
      expect(result[:overtime_50]).to eq(0.0)
      expect(result[:overtime_bonus]).to eq(0.0)
    end

    it 'returns zero leave days' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:leave_days_cp]).to eq(0.0)
      expect(result[:leave_days_rtt]).to eq(0.0)
      expect(result[:leave_days_sick]).to eq(0.0)
      expect(result[:leave_deduction]).to eq(0.0)
    end

    it 'includes the estimatif note' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:note]).to include('Estimatif')
    end
  end

  # ── Break duration subtracted from worked_hours ──────────────────────────────

  describe 'break_duration_minutes deduction' do
    it 'subtracts break from duration in worked_hours calculation' do
      # 480 gross - 60 break = 420 net = 7.0h
      entry = make_entry(duration_minutes: 480, break_duration_minutes: 60)
      result = call(preloaded_te: [entry], preloaded_lr: [])
      expect(result[:worked_hours]).to eq(7.0)
    end

    it 'clamps negative net duration to zero' do
      # pathological: break > duration (data corruption guard)
      entry = make_entry(duration_minutes: 30, break_duration_minutes: 60)
      result = call(preloaded_te: [entry], preloaded_lr: [])
      expect(result[:worked_hours]).to eq(0.0)
    end

    it 'handles zero break_duration_minutes' do
      entry = make_entry(duration_minutes: 420, break_duration_minutes: 0)
      result = call(preloaded_te: [entry], preloaded_lr: [])
      expect(result[:worked_hours]).to eq(7.0)
    end
  end

  # ── Part-time prorating ──────────────────────────────────────────────────────

  describe 'part_time_rate prorating' do
    # gross_salary_cents stores the ACTUAL (part-time) salary already.
    # The service divides by part_time_rate to derive the FTE equivalent,
    # then multiplies back — so base_salary == gross_salary regardless of rate.
    # What changes is the contractual_hours (proportional to weekly_hours / rate).
    before { employee.update!(part_time_rate: 0.8) }

    it 'returns base_salary equal to stored gross_salary (prorating cancels)' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:base_salary]).to eq(3000.0)
    end

    it 'returns a positive gross_total' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:gross_total]).to be > 0
    end

    it 'does not apply overtime for part-time employees with no extra hours' do
      result = call(preloaded_te: [], preloaded_lr: [])
      expect(result[:overtime_25]).to eq(0.0)
    end
  end

  # ── Overtime calculation ─────────────────────────────────────────────────────

  describe 'overtime calculation' do
    # February 2026: 20 business days → contractual hours = 35/5 * 20 = 140h
    # 8h/week cap × ~4 weeks = 32h at +25%, beyond = +50%

    it 'assigns overtime to +25% bucket when below weekly cap' do
      # Add 10 extra hours of overtime (below 32h monthly cap)
      entries = [make_entry(duration_minutes: (140 + 10) * 60)]
      result = call(preloaded_te: entries, preloaded_lr: [])
      expect(result[:overtime_25]).to be > 0
      expect(result[:overtime_50]).to eq(0.0)
    end

    it 'splits overtime into +25% and +50% when above weekly cap' do
      # Add 50 extra hours — well above 8h/week × ~4 weeks = ~32h cap
      entries = [make_entry(duration_minutes: (140 + 50) * 60)]
      result = call(preloaded_te: entries, preloaded_lr: [])
      expect(result[:overtime_25]).to be > 0
      expect(result[:overtime_50]).to be > 0
    end

    it 'computes a positive overtime_bonus when overtime exists' do
      entries = [make_entry(duration_minutes: (140 + 10) * 60)]
      result = call(preloaded_te: entries, preloaded_lr: [])
      expect(result[:overtime_bonus]).to be > 0
    end

    it 'returns zero overtime when worked_hours equals contractual_hours' do
      business_days = (period..period.end_of_month).count { |d| d.on_weekday? }
      contractual   = (35.0 / 5.0) * business_days
      entries = [make_entry(duration_minutes: (contractual * 60).to_i)]
      result = call(preloaded_te: entries, preloaded_lr: [])
      expect(result[:overtime_25]).to eq(0.0)
      expect(result[:overtime_50]).to eq(0.0)
    end
  end

  # ── Leave days by type ───────────────────────────────────────────────────────

  describe 'leave_days_by_type' do
    it 'counts CP days correctly' do
      leave = make_leave(leave_type: 'CP', days_count: 5.0)
      result = call(preloaded_te: [], preloaded_lr: [leave])
      expect(result[:leave_days_cp]).to eq(5.0)
    end

    it 'counts RTT days correctly' do
      leave = make_leave(leave_type: 'RTT', days_count: 2.0)
      result = call(preloaded_te: [], preloaded_lr: [leave])
      expect(result[:leave_days_rtt]).to eq(2.0)
    end

    it 'counts sick days correctly' do
      leave = make_leave(leave_type: 'Maladie', days_count: 3.0)
      result = call(preloaded_te: [], preloaded_lr: [leave])
      expect(result[:leave_days_sick]).to eq(3.0)
    end

    it 'deducts Sans_Solde from gross_total' do
      leave = make_leave(leave_type: 'Sans_Solde', days_count: 2.0)
      result = call(preloaded_te: [], preloaded_lr: [leave])
      expect(result[:leave_deduction]).to be > 0
      expect(result[:gross_total]).to be < result[:base_salary]
    end

    it 'ignores auto_approved leaves the same as approved' do
      leave = make_leave(leave_type: 'CP', days_count: 3.0, status: 'auto_approved')
      result = call(preloaded_te: [], preloaded_lr: [leave])
      expect(result[:leave_days_cp]).to eq(3.0)
    end

    it 'sums multiple leaves of different types' do
      leaves = [
        make_leave(leave_type: 'CP',      days_count: 2.0),
        make_leave(leave_type: 'RTT',     days_count: 1.0),
        make_leave(leave_type: 'Maladie', days_count: 1.0)
      ]
      result = call(preloaded_te: [], preloaded_lr: leaves)
      expect(result[:leave_days_cp]).to   eq(2.0)
      expect(result[:leave_days_rtt]).to  eq(1.0)
      expect(result[:leave_days_sick]).to eq(1.0)
    end
  end

  # ── Preload fallback (AR queries) ────────────────────────────────────────────

  describe 'AR fallback when no preloaded collections given' do
    it 'queries time_entries from DB and returns correct worked_hours' do
      create(:time_entry,
             employee:               employee,
             organization:           org,
             clock_in:               period.to_time + 9.hours,
             clock_out:              period.to_time + 16.hours,
             duration_minutes:       420,
             break_duration_minutes: 0,
             validated_at:           period.to_time + 17.hours)

      result = described_class.new(employee, period).call
      expect(result[:worked_hours]).to eq(7.0)
    end

    it 'queries leave_requests from DB and returns correct CP days' do
      create(:leave_request,
             employee:     employee,
             organization: org,
             leave_type:   'CP',
             status:       'approved',
             days_count:   3.0,
             start_date:   period,
             end_date:     period + 4.days)

      result = described_class.new(employee, period).call
      expect(result[:leave_days_cp]).to eq(3.0)
    end
  end

  # ── Tenant isolation ─────────────────────────────────────────────────────────

  describe 'tenant isolation (AR fallback path)' do
    let(:org_b)      { create(:organization) }
    let(:emp_b)      { create(:employee, organization: org_b) }

    it 'does not pick up time entries from another organization' do
      # Entry belongs to org_b employee but we query under org_a tenant
      ActsAsTenant.with_tenant(org_b) do
        create(:time_entry,
               employee:         emp_b,
               organization:     org_b,
               clock_in:         period.to_time + 9.hours,
               clock_out:        period.to_time + 16.hours,
               duration_minutes: 420,
               validated_at:     period.to_time + 17.hours)
      end

      result = described_class.new(employee, period).call
      expect(result[:worked_hours]).to eq(0.0)
    end
  end
end
