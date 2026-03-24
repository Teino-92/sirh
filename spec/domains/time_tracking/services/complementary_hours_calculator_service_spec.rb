# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComplementaryHoursCalculatorService do
  let(:org)      { create(:organization, plan: 'sirh') }
  let(:employee) { create(:employee, organization: org) }
  let(:week_start) { Date.current.beginning_of_week }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  # Helper — creates completed time entries spread across days (max 9h/day to respect the 10h legal limit)
  def create_time_entries(hours:, ws: week_start)
    remaining = hours.to_f
    day = 0
    while remaining > 0
      day_hours = [remaining, 9.0].min
      date = ws + day.days
      create(:time_entry,
             employee:         employee,
             organization:     org,
             clock_in:         date.to_time + 8.hours,
             clock_out:        date.to_time + 8.hours + day_hours.hours,
             duration_minutes: (day_hours * 60).to_i)
      remaining -= day_hours
      day += 1
    end
  end

  def call(ws: week_start)
    described_class.new(employee, week_start: ws).call
  end

  # ─── Applicability ───────────────────────────────────────────────────────────

  context 'when employee is full-time (weekly_hours >= 35)' do
    before { create(:work_schedule, employee: employee, organization: org, weekly_hours: 35) }

    it 'returns applicable: false without calculating' do
      result = call
      expect(result.applicable).to be false
      expect(result.over_legal).to be false
    end
  end

  context 'when employee has no work_schedule' do
    it 'returns applicable: false' do
      expect(call.applicable).to be false
    end
  end

  # ─── Limit calculations ───────────────────────────────────────────────────────

  context 'with a 17.5h part-time contract (legal regime)' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org, weekly_hours: 17.5) }

    it 'computes correct legal_limit (10%)' do
      expect(call.legal_limit).to eq(1.75)
    end

    it 'computes correct conventional_limit (33%)' do
      expect(call.conventional_limit).to eq(5.83)
    end

    it 'uses legal_limit as active_limit by default' do
      expect(call.active_limit).to eq(1.75)
    end

    it 'sets ceiling to contractual + legal_limit (19.25 < 34)' do
      expect(call.ceiling).to eq(19.25)
    end
  end

  context 'with a 24h part-time contract (legal regime)' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org) }

    it 'computes legal_limit = 2.4' do
      expect(call.legal_limit).to eq(2.4)
    end

    it 'computes ceiling = 26.4' do
      expect(call.ceiling).to eq(26.4)
    end
  end

  context 'with a 30h contract (legal regime) — ceiling capped at 34h' do
    before { create(:work_schedule, employee: employee, organization: org, weekly_hours: 30) }

    it 'caps ceiling at 34h (not 30 + 10 = 33h which is below 34)' do
      # 30 + 3.0 (10%) = 33.0, which is less than 34 → ceiling = 33.0
      expect(call.ceiling).to eq(33.0)
    end
  end

  # ─── Complementary hours counted correctly ───────────────────────────────────

  context 'with a 17.5h contract and 17h worked' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org, weekly_hours: 17.5) }

    it 'reports zero complementary hours' do
      create_time_entries(hours: 17)
      result = call
      expect(result.complementary).to eq(0.0)
      expect(result.over_legal).to be false
    end
  end

  context 'with a 17.5h contract and 19h worked (under legal limit)' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org, weekly_hours: 17.5) }

    it 'is not over_legal (19 - 17.5 = 1.5h < legal limit 1.75h)' do
      create_time_entries(hours: 19)
      result = call
      expect(result.complementary).to eq(1.5)
      expect(result.over_legal).to be false
      expect(result.over_conventional).to be false
    end
  end

  context 'with a 17.5h contract and 20h worked' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org, weekly_hours: 17.5) }

    it 'flags over_legal (20 - 17.5 = 2.5 > legal limit 1.75)' do
      create_time_entries(hours: 20)
      result = call
      expect(result.complementary).to eq(2.5)
      expect(result.over_legal).to be true
      expect(result.over_conventional).to be false # 2.5 < 5.83
    end
  end

  context 'with a 17.5h contract and 24h worked (over conventional)' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org, weekly_hours: 17.5) }

    it 'flags both over_legal and over_conventional' do
      create_time_entries(hours: 24)
      result = call
      expect(result.over_legal).to be true
      expect(result.over_conventional).to be true  # 24 - 17.5 = 6.5 > 5.83
    end
  end

  # ─── Near ceiling ────────────────────────────────────────────────────────────

  context 'near_ceiling flag (within 1h of ceiling)' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org) }
    # 24h contract, ceiling = 26.4

    it 'is false when 2h away from ceiling' do
      create_time_entries(hours: 24)
      expect(call.near_ceiling).to be false  # 24 < 26.4 - 1.0 = 25.4
    end

    it 'is true when within 1h of ceiling' do
      create_time_entries(hours: 26)
      expect(call.near_ceiling).to be true  # 26 >= 25.4
    end
  end

  # ─── Regime sensitivity ──────────────────────────────────────────────────────

  context 'with conventional regime org' do
    let(:org) { create(:organization, plan: 'sirh', settings: { 'complementary_hours_regime' => 'conventional' }) }

    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org) }

    it 'uses conventional_limit as active_limit' do
      result = call
      expect(result.regime).to eq('conventional')
      expect(result.active_limit).to eq(result.conventional_limit)
    end

    it 'is not over_legal with 25h (25 - 24 = 1h < legal limit 2.4h)' do
      create_time_entries(hours: 25)
      result = call
      expect(result.over_legal).to be false
      expect(result.over_conventional).to be false  # 1h < conventional 8h
    end
  end

  # ─── Multi-tenant isolation ───────────────────────────────────────────────────

  context 'multi-tenant isolation' do
    let(:org2)      { create(:organization, plan: 'sirh', settings: { 'complementary_hours_regime' => 'conventional' }) }
    let(:employee2) { create(:employee, organization: org2) }

    before do
      create(:work_schedule, :part_time_24h, employee: employee, organization: org)
      ActsAsTenant.without_tenant do
        create(:work_schedule, :part_time_24h, employee: employee2, organization: org2)
      end
    end

    it 'each employee gets their own org regime' do
      r1 = described_class.new(employee, week_start: week_start).call
      r2 = ActsAsTenant.without_tenant { described_class.new(employee2, week_start: week_start).call }
      expect(r1.regime).to eq('legal')
      expect(r2.regime).to eq('conventional')
    end
  end

  # ─── Week scoping ─────────────────────────────────────────────────────────────

  context 'week scoping' do
    before { create(:work_schedule, :part_time_24h, employee: employee, organization: org) }

    it 'does not count entries from previous week' do
      prev_week = week_start - 7.days
      create_time_entries(hours: 27, ws: prev_week)  # Over limit last week
      result = call(ws: week_start)
      expect(result.worked).to eq(0.0)
      expect(result.over_legal).to be false
    end

    it 'only counts completed entries (with clock_out)' do
      # Active entry (no clock_out) — should not count
      create(:time_entry,
             employee: employee, organization: org,
             clock_in: week_start.to_time + 8.hours,
             clock_out: nil,
             duration_minutes: 0)
      expect(call.worked).to eq(0.0)
    end
  end
end
