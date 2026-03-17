# frozen_string_literal: true

# Retry ActionMailer::MailDeliveryJob on transient SMTP errors (timeout, connection reset).
# Without this, a single Resend hiccup surfaces as an unhandled exception in Sentry.
Rails.application.config.after_initialize do
  ActionMailer::MailDeliveryJob.retry_on(
    Net::OpenTimeout,
    Net::ReadTimeout,
    EOFError,
    wait: :polynomially_longer,
    attempts: 3
  )
end
