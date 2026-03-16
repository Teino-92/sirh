# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkScheduleSerializer do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org) }
  let(:schedule) { create(:work_schedule, :full_time_35h, employee: employee) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe '#as_json' do
    subject(:data) { described_class.new(schedule).as_json }

    it 'includes all fields' do
      expect(data).to include(
        id:               schedule.id,
        name:             schedule.name,
        weekly_hours:     schedule.weekly_hours,
        schedule_pattern: schedule.schedule_pattern
      )
    end

    it 'does not expose employee_id or sensitive fields' do
      expect(data).not_to have_key(:employee_id)
      expect(data).not_to have_key(:organization_id)
    end
  end
end
