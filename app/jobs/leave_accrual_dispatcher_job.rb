# frozen_string_literal: true

# Dispatcher: enqueues one OrganizationLeaveAccrualJob per active organization.
# Run monthly (1st of month). Each org is processed independently and in parallel.
# If one org fails, the others are unaffected.
class LeaveAccrualDispatcherJob < ApplicationJob
  queue_as :schedulers

  def perform
    Rails.logger.info "[LeaveAccrualDispatcher] Dispatching CP accrual for #{Organization.count} organizations"

    Organization.find_each do |organization|
      OrganizationLeaveAccrualJob.perform_later(organization.id)
    end
  end
end
