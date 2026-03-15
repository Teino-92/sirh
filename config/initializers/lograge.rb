# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = Rails.env.production?

  # Emit structured JSON — easily parsed by Render / Papertrail / Datadog
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Enrich each log line with useful context
  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:headers]&.fetch('action_dispatch.request_id', nil),
      user_id:    event.payload[:current_user_id],
      org_id:     event.payload[:current_org_id],
      duration:   event.duration.round(2),
    }.compact
  end
end
