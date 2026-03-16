require "active_support/core_ext/integer/time"

# Staging mirrors production exactly, with two differences:
#   1. HTTP Basic Auth gate (added in ApplicationController — see STAGING_AUTH env vars)
#   2. Seeds auto-loaded on deploy (see bin/render-build-staging.sh)

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.require_master_key = true
  config.assets.compile = false

  config.assume_ssl = true
  config.force_ssl = true

  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  config.log_tags  = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.cache_store = :memory_store
  config.active_job.queue_adapter = :async

  config.action_mailer.perform_caching  = false
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_deliveries   = false  # no emails sent from staging

  config.action_mailer.default_url_options = {
    host:     ENV.fetch('APP_HOST', 'staging.izi-rh.com'),
    protocol: 'https'
  }

  config.action_controller.default_url_options = {
    host:     ENV.fetch('APP_HOST', 'staging.izi-rh.com'),
    protocol: 'https'
  }

  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  config.active_storage.service = ENV.fetch("STORAGE_SERVICE", "cloudinary").to_sym

  render_host = ENV['RENDER_EXTERNAL_HOSTNAME']
  app_host    = ENV.fetch('APP_HOST', 'staging.izi-rh.com')
  config.hosts = [app_host, render_host].compact.uniq
  config.host_authorization = { exclude: ->(request) { request.path == '/up' } }
end
