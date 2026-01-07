ActsAsTenant.configure do |config|
  # Don't require tenant globally - allows Devise authentication
  # Security is ensured by set_tenant in ApplicationController
  config.require_tenant = false

  # Primary key for tenant model
  config.pkey = :id
end
