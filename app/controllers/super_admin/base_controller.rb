# frozen_string_literal: true

module SuperAdmin
  class BaseController < ActionController::Base
    # Completely independent from Devise — no DB account needed
    http_basic_authenticate_with(
      name:     ENV.fetch('SUPER_ADMIN_LOGIN', Rails.env.production? ? nil : 'admin'),
      password: ENV.fetch('SUPER_ADMIN_PASSWORD', Rails.env.production? ? nil : 'admin')
    )

    layout 'super_admin'
  end
end
