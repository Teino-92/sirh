source "https://rubygems.org"

ruby "3.3.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.6"

# CSV parsing (will be extracted from stdlib in Ruby 3.4+)
gem "csv"
gem "roo", "~> 2.10" # XLSX/XLS/CSV import support

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem "dotenv-rails", groups: [:development, :test]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]

  # RSpec testing framework
  gem "rspec-rails", "~> 6.1"

  # Test fixtures and factories
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.2"

  # Additional matchers for RSpec
  gem "shoulda-matchers", "~> 6.0"

  # Time travel for testing
  gem "timecop", "~> 0.9"

  # Code coverage
  gem "simplecov", "~> 0.22", require: false

  # HTTP request stubbing
  gem "webmock", "~> 3.23"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Security scanner for Rails [https://github.com/presidentbeef/brakeman]
  gem "brakeman", require: false

  # N+1 query detection [https://github.com/flyerhzm/bullet]
  gem "bullet"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

gem "ostruct"
gem "devise", "~> 4.9"
gem "devise-jwt", "~> 0.12.1" # JWT authentication for API
gem "pundit", "~> 2.5"
gem "solid_queue"
gem "solid_cache"
gem "aws-sdk-s3", require: false  # Active Storage S3 backend (avatars)
gem "rack-attack" # Rate limiting and request throttling

# Multi-tenancy [https://github.com/ErwinM/acts_as_tenant]
gem "acts_as_tenant"

# Audit trail [https://github.com/paper-trail-gem/paper_trail]
gem "paper_trail"

# Pagination [https://github.com/kaminari/kaminari]
gem "kaminari"

# HTTP client for external APIs (Anthropic)
gem "faraday", "~> 2.7"
gem "faraday-retry", "~> 2.2"

# Stripe billing
gem "stripe", "~> 13.0"

# Error tracking + profiling
gem "stackprof", require: false
gem "sentry-ruby", "~> 5.21"
gem "sentry-rails", "~> 5.21"

# Structured JSON logging
gem "lograge", "~> 0.14"

gem "cloudinary", "~> 2.4"
