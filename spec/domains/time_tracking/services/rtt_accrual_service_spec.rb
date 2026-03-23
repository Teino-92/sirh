# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RttAccrualService do
  let(:org)      { create(:organization, plan: 'sirh', settings: { 'rtt_enabled' => true }) }
  let(:employee) { create(:employee, organization: org) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  # Creates time entries spread across days to respect the 10h/day legal limit.
  def create_time_entries_for_week(hours:, week_start: Date.current.beginning_of_week)
    hours_per_day = [hours, 9].min  # max 9h per entry to stay under 10h limit
    remaining = hours
    day = 0
    while remaining > 0
      day_hours = [remaining, hours_per_day].min
      date = week_start + day.days
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

  describe '#calculate_and_accrue_weekly' do
    context 'when RTT is disabled on the organization' do
      let(:org) { create(:organization, plan: 'sirh', settings: { 'rtt_enabled' => false }) }

      it 'does nothing' do
        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).and_return(policy_engine)
        expect(policy_engine).not_to receive(:accrue_rtt!)

        described_class.new(employee).calculate_and_accrue_weekly
      end
    end

    context 'when RTT is enabled' do
      it 'calls accrue_rtt! with hours worked this week' do
        create_time_entries_for_week(hours: 39)

        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).with(employee).and_return(policy_engine)
        expect(policy_engine).to receive(:accrue_rtt!).with(39.0, period_weeks: 1)

        described_class.new(employee).calculate_and_accrue_weekly
      end

      it 'passes 0.0 hours when no time entries exist this week' do
        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).with(employee).and_return(policy_engine)
        expect(policy_engine).to receive(:accrue_rtt!).with(0.0, period_weeks: 1)

        described_class.new(employee).calculate_and_accrue_weekly
      end

      it 'only counts time entries within the current week' do
        # Entry last week — should not be counted
        last_week = Date.current.beginning_of_week - 7
        create(:time_entry,
               employee:         employee,
               organization:     org,
               clock_in:         last_week.to_time + 8.hours,
               clock_out:        last_week.to_time + 18.hours,
               duration_minutes: 600)

        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).and_return(policy_engine)
        expect(policy_engine).to receive(:accrue_rtt!).with(0.0, period_weeks: 1)

        described_class.new(employee).calculate_and_accrue_weekly
      end

      it 'only counts completed time entries (with clock_out)' do
        create(:time_entry, :active, employee: employee, organization: org)

        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).and_return(policy_engine)
        expect(policy_engine).to receive(:accrue_rtt!).with(0.0, period_weeks: 1)

        described_class.new(employee).calculate_and_accrue_weekly
      end
    end
  end

  describe '#calculate_and_accrue_monthly' do
    context 'when RTT is disabled on the organization' do
      let(:org) { create(:organization, plan: 'sirh', settings: { 'rtt_enabled' => false }) }

      it 'does nothing' do
        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).and_return(policy_engine)
        expect(policy_engine).not_to receive(:accrue_rtt!)

        described_class.new(employee).calculate_and_accrue_monthly
      end
    end

    context 'when RTT is enabled' do
      it 'calls accrue_rtt! with correct hours and week count for the month' do
        month_start = Date.current.beginning_of_month
        # 5 entries × 8h = 40h spread across 5 days (stays under 10h/day limit)
        5.times do |i|
          date = month_start + i.days
          create(:time_entry,
                 employee:         employee,
                 organization:     org,
                 clock_in:         date.to_time + 8.hours,
                 clock_out:        date.to_time + 16.hours,
                 duration_minutes: 480)
        end

        weeks_in_month = ((Date.current.end_of_month - month_start) / 7.0).ceil

        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).with(employee).and_return(policy_engine)
        expect(policy_engine).to receive(:accrue_rtt!).with(40.0, period_weeks: weeks_in_month)

        described_class.new(employee).calculate_and_accrue_monthly
      end

      it 'passes 0.0 hours when no entries exist this month' do
        weeks_in_month = ((Date.current.end_of_month - Date.current.beginning_of_month) / 7.0).ceil

        policy_engine = instance_double(LeavePolicyEngine)
        allow(LeavePolicyEngine).to receive(:new).with(employee).and_return(policy_engine)
        expect(policy_engine).to receive(:accrue_rtt!).with(0.0, period_weeks: weeks_in_month)

        described_class.new(employee).calculate_and_accrue_monthly
      end
    end
  end
end
