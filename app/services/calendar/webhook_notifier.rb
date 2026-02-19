# frozen_string_literal: true

require 'net/http'
require 'json'

# CalendarWebhookNotifier fires a POST webhook whenever a calendar-relevant event
# occurs (1:1 scheduled or training assigned). The webhook URL and provider are
# configured per-organization in organization.settings.
#
# This is intentionally provider-agnostic: the webhook consumer (e.g. N8n) is
# responsible for routing to the actual calendar service (Calendly, Google
# Calendar, Outlook, etc.) based on its own workflow configuration.
#
# Payload schema (JSON):
#   {
#     "event":        "one_on_one.scheduled" | "training_assignment.created",
#     "organization": { "id", "name" },
#     "provider":     "n8n" | "calendly" | "google" | "outlook" | null,
#     "record": {
#       "id", "type",
#       ... event-specific fields ...
#     }
#   }
#
# The response body is expected to optionally contain:
#   { "calendar_event_id": "<external-id>" }
# If present, it will be stored in record.metadata["calendar_event_id"].
#
module Calendar
  class WebhookNotifier
    TIMEOUT_SECONDS = 10

    def initialize(organization)
      @organization = organization
    end

    def notify(event_name, record, payload)
      webhook_url = @organization.settings['calendar_webhook_url'].presence
      return unless webhook_url

      body = {
        event: event_name,
        organization: {
          id:   @organization.id,
          name: @organization.name
        },
        provider: @organization.settings['calendar_provider'],
        record:   payload
      }.to_json

      response = fire_request(webhook_url, body)
      store_calendar_event_id(record, response) if response
    rescue StandardError => e
      Rails.logger.error "[CalendarWebhook] Failed for #{event_name}: #{e.message}"
    end

    private

    def fire_request(url, body)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = (uri.scheme == 'https')
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request.body = body

      http.request(request)
    end

    def store_calendar_event_id(record, response)
      return unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      event_id = data['calendar_event_id'].presence
      return unless event_id

      record.update_column(:metadata, record.metadata.merge('calendar_event_id' => event_id))
    rescue JSON::ParserError
      # Webhook responded with non-JSON — that's fine, just ignore
    end
  end
end
