# frozen_string_literal: true

# Dispatcher: enqueues one OrganizationRttAccrualJob per organization with RTT enabled.
# Run weekly (every Monday). Each org is processed independently and in parallel.
class RttAccrualDispatcherJob < ApplicationJob
  queue_as :schedulers

  def perform(week_start_date = nil)
    week_start = week_start_date&.to_date || Date.current.last_week.beginning_of_week

    Rails.logger.info "[RttAccrualDispatcher] Dispatching RTT accrual for week #{week_start}"

    Organization.find_each do |organization|
      next unless organization.rtt_enabled?

      OrganizationRttAccrualJob.perform_later(organization.id, week_start.to_s)
    end
  end
end
