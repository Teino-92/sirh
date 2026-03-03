# frozen_string_literal: true

# Pushes a locked payroll period's data to the organization's Silae webhook.
#
# Enqueued by Admin::PayrollController#push_silae after HR confirms.
# Idempotent: safe to run multiple times for the same (org, period).
#
# Job arguments contain NO PII — serialization happens inside perform.
class PayrollWebhookJob < ApplicationJob
  queue_as :critical

  # Retry up to 5 times with polynomial backoff (~1s, ~4s, ~9s, ~16s, ~25s)
  # covering transient Silae outages without flooding.
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError
  discard_on ArgumentError

  def perform(organization_id, period_string)
    org = Organization.find_by(id: organization_id)
    return unless org&.payroll_webhook_url.present?

    period = Date.parse(period_string).beginning_of_month

    # Guard: abort silently if the period was unlocked between enqueue and execution
    return unless ActsAsTenant.with_tenant(org) {
      PayrollPeriod.exists?(organization_id: org.id, period: period)
    }

    ActsAsTenant.with_tenant(org) do
      payload = Payroll::PayrollWebhookSerializer.new(org, period).as_json
      Payroll::WebhookPusher.new(org).push(payload)
    end

    log_push(org, period, status: 'success')
  rescue StandardError => e
    log_push(org, period, status: 'failure', error: e.message) if defined?(org) && org
    raise
  end

  private

  def log_push(org, period, status:, error: nil)
    meta = { period: period.strftime('%Y-%m'), status: status }
    meta[:error] = error.truncate(500) if error.present?

    PaperTrail::Version.create!(
      item_type:       'Organization',
      item_id:         org.id,
      event:           'payroll_webhook_push',
      whodunnit:       'system',
      organization_id: org.id,
      object_changes:  meta.to_json
    )
  rescue StandardError => e
    Rails.logger.error("[PayrollWebhookJob] log_push failed: #{e.message}")
  end
end
