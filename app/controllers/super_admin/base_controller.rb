# frozen_string_literal: true

module SuperAdmin
  class BaseController < ActionController::Base
    # Completely independent from Devise — no DB account needed
    http_basic_authenticate_with(
      name:     ENV.fetch('SUPER_ADMIN_LOGIN',    'matteo'),
      password: ENV.fetch('SUPER_ADMIN_PASSWORD', 'changeme')
    )

    layout 'admin'
  end
end
