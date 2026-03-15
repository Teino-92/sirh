# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV.fetch('SENTRY_DSN', 'https://599a82dfde25b891526cefcb3bf2f512@o4511050440310784.ingest.de.sentry.io/4511050445750352')

  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Enable Sentry Logs (SDK 5.9+)
  config.enable_logs = true
  config.enabled_patches = [:logger]

  # PII — activé pour avoir les headers/IP en prod (pas de données perso sensibles exposées)
  config.send_default_pii = true

  # Traces: 100% en prod pour commencer, à réduire si volume élevé
  config.traces_sample_rate = 1.0

  # Profiling (requires stackprof)
  config.profiles_sample_rate = 1.0
end
