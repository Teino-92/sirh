# frozen_string_literal: true

Stripe.api_key = if Rails.env.production?
  ENV.fetch("STRIPE_SECRET_KEY") { raise "STRIPE_SECRET_KEY must be set in production" }
else
  ENV["STRIPE_SECRET_KEY"]
end

Stripe.api_version = "2024-06-20"
