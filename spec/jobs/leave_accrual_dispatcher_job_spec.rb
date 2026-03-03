# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveAccrualDispatcherJob, type: :job do
  include ActiveJob::TestHelper

  let!(:org1) { create(:organization) }
  let!(:org2) { create(:organization) }

  describe '#perform' do
    it 'enqueues one OrganizationLeaveAccrualJob per organization' do
      expect do
        described_class.perform_now
      end.to have_enqueued_job(OrganizationLeaveAccrualJob).exactly(Organization.count).times
    end

    it 'enqueues jobs for each organization id' do
      described_class.perform_now

      expect(OrganizationLeaveAccrualJob).to have_been_enqueued.with(org1.id)
      expect(OrganizationLeaveAccrualJob).to have_been_enqueued.with(org2.id)
    end

    it 'runs on the schedulers queue' do
      expect(described_class.new.queue_name).to eq('schedulers')
    end
  end
end
