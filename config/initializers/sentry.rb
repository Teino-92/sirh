# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']

  # Only enable in production — avoid noise in dev/test
  config.enabled_environments = %w[production]

  # Capture 10% of transactions for performance monitoring
  config.traces_sample_rate = 0.1

  # Filter out low-signal errors
  config.excluded_exceptions += %w[
    ActionController::RoutingError
    ActionController::UnknownFormat
    Rack::Attack::InsufficientScope
  ]

  # Scrub sensitive parameters
  config.send_default_pii = false
end
