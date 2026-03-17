# frozen_string_literal: true

class SyncSeatCountJob < ApplicationJob
  queue_as :default

  def perform(organization_id)
    org = ActsAsTenant.without_tenant { Organization.find_by(id: organization_id) }
    return unless org

    SeatSyncService.new(org).sync!
  end
end
