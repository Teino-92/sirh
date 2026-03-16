# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TimeEntrySerializer do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org) }
  let(:entry)    { create(:time_entry, employee: employee, clock_out: nil) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe '#as_json' do
    subject(:data) { described_class.new(entry).as_json }

    it 'includes all fields' do
      expect(data).to include(
        id:               entry.id,
        clock_in:         entry.clock_in,
        clock_out:        entry.clock_out,
        duration_minutes: entry.duration_minutes,
        hours_worked:     entry.hours_worked,
        active:           entry.active?,
        overtime:         entry.overtime?,
        worked_date:      entry.worked_date,
        location:         entry.location
      )
    end

    it 'reflects active state when no clock_out' do
      expect(data[:active]).to be true
      expect(data[:clock_out]).to be_nil
    end

    context 'with a completed entry' do
      let(:entry) { create(:time_entry, employee: employee, clock_out: 1.hour.from_now) }

      it 'is not active' do
        expect(data[:active]).to be false
      end
    end
  end
end
