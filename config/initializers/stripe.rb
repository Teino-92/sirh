# frozen_string_literal: true

Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
Stripe.api_version = "2024-06-20"

# Validation au boot du serveur uniquement (pas pendant assets:precompile)
Rails.application.config.after_initialize do
  if Rails.env.production? && ENV["STRIPE_SECRET_KEY"].blank?
    raise "STRIPE_SECRET_KEY must be set in production"
  end
end
