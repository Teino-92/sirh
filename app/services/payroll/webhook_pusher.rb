# frozen_string_literal: true

require 'net/http'
require 'json'

module Payroll
  # Fires a POST to the organization's configured Silae webhook URL.
  #
  # Sends the full payroll JSON payload for the locked period.
  # The secret (if configured) is sent as: Authorization: Bearer <secret>
  #
  # Raises StandardError on HTTP failure or non-2xx response, so the caller
  # (PayrollWebhookJob) can retry via its retry_on policy.
  class WebhookPusher
    TIMEOUT_SECONDS = 15

    def initialize(organization)
      @org = organization
    end

    def push(payload)
      url = @org.payroll_webhook_url
      raise ArgumentError, 'No payroll_webhook_url configured' if url.blank?

      body = payload.to_json
      response = fire_request(url, body)

      unless response.is_a?(Net::HTTPSuccess)
        raise "Silae webhook responded #{response.code}: #{response.body.truncate(200)}"
      end

      response
    end

    private

    def fire_request(url, body)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = (uri.scheme == 'https')
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@org.payroll_webhook_secret}" if @org.payroll_webhook_secret.present?
      request.body = body

      http.request(request)
    end
  end
end
