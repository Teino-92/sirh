# frozen_string_literal: true

# Configuration for ActsAsTenant in tests
RSpec.configure do |config|
  config.before(:each) do
    # Reset tenant context before each test
    ActsAsTenant.current_tenant = nil
  end

  config.after(:each) do
    # Clean up tenant context after each test
    ActsAsTenant.current_tenant = nil
  end
end
