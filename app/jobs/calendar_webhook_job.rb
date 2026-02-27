# frozen_string_literal: true

# Fires a calendar webhook notification asynchronously so the HTTP call to the
# external service (N8n, Calendly, etc.) never blocks the Rails request cycle.
#
# Usage:
#   CalendarWebhookJob.perform_later(event_name, record_class, record_id, payload)
#
class CalendarWebhookJob < ApplicationJob
  queue_as :default

  ALLOWED_RECORD_CLASSES = %w[OneOnOne TrainingAssignment].freeze

  # Retry up to 3 times with exponential back-off; after that give up silently
  # to avoid flooding external services with stale events.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(event_name, record_class, record_id, payload)
    raise ArgumentError, "Unauthorized record class: #{record_class}" unless ALLOWED_RECORD_CLASSES.include?(record_class)

    record = record_class.constantize.find_by(id: record_id)
    return unless record

    notifier = Calendar::WebhookNotifier.new(record.organization)
    notifier.notify(event_name, record, payload)
  end
end
