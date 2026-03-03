# frozen_string_literal: true

require 'rails_helper'

# We test JsonbValidatable via the Organization model which already includes it
# and declares: validates_jsonb_keys :settings, types: { work_week_hours: Numeric, ... }
RSpec.describe JsonbValidatable, type: :model do
  let(:org) { build(:organization) }

  context 'when settings is nil' do
    before { org.settings = nil }

    it 'is valid' do
      expect(org).to be_valid
    end
  end

  context 'when settings is a valid hash with known numeric key' do
    before { org.settings = { 'work_week_hours' => 35, 'cp_acquisition_rate' => 2.5 } }

    it 'is valid' do
      expect(org).to be_valid
    end
  end

  context 'when a type check fails (string instead of Numeric)' do
    before { org.settings = { 'work_week_hours' => 'not_a_number' } }

    it 'adds a type error' do
      org.valid?
      expect(org.errors[:settings].to_s).to include('work_week_hours')
    end
  end

  # String settings are not valid on Organization (other callbacks enforce Hash)
  # but the concern itself skips non-Hash values — tested via TimeEntry below

  # TimeEntry uses validates_jsonb_keys with allowed: constraint
  context 'with allowed keys constraint (TimeEntry)' do
    let(:employee) { build(:employee) }
    let(:time_entry) do
      build(:time_entry,
            employee: employee,
            organization: employee.organization,
            location: location_value)
    end

    context 'when location is a valid hash with allowed keys' do
      let(:location_value) { { 'latitude' => 48.8566, 'longitude' => 2.3522 } }

      it 'is valid' do
        expect(time_entry).to be_valid
      end
    end

    context 'when location contains an unknown key' do
      let(:location_value) { { 'latitude' => 48.8566, 'unknown_field' => 'x' } }

      it 'adds an error' do
        time_entry.valid?
        expect(time_entry.errors[:location].to_s).to include('inconnue')
      end
    end

    context 'when location is nil' do
      let(:location_value) { nil }

      it 'is valid (location is optional)' do
        expect(time_entry).to be_valid
      end
    end

    context 'when location is a string (legacy)' do
      let(:location_value) { 'Office' }

      it 'skips validation' do
        expect(time_entry).to be_valid
      end
    end
  end
end
