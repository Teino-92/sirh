# frozen_string_literal: true

class Rack::Attack
  ### Configure Cache ###

  # Use Rails cache (defaults to MemoryStore in dev, Redis recommended for production)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Spammy Clients ###

  # Throttle all requests by IP (60rpm)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  ### Prevent Brute-Force Login Attacks ###

  # Throttle POST requests to /api/v1/login by IP address
  # Allow 5 login attempts per 20 seconds
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/login' && req.post?
      req.ip
    end
  end

  # Throttle POST requests to /api/v1/login by email param
  # Protect against distributed brute-force attacks
  # Allow 10 login attempts per 5 minutes per email
  throttle('logins/email', limit: 10, period: 5.minutes) do |req|
    if req.path == '/api/v1/login' && req.post?
      # Extract email from JSON body
      req.params['email']&.to_s&.downcase&.presence
    end
  end

  ### Throttle API Requests per Authenticated User ###

  # Allow authenticated users higher rate limits
  # 100 requests per minute per user
  throttle('api/user', limit: 100, period: 1.minute) do |req|
    if req.path.start_with?('/api') && req.env['warden']&.user
      req.env['warden'].user.id
    end
  end

  ### Custom Throttle Response ###

  # When a client is throttled, return 429 with Retry-After header
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => (match_data[:period] - (now % match_data[:period])).to_s,
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - (now % match_data[:period]))).to_s
    }

    [429, headers, [{ error: 'Too many requests. Please try again later.' }.to_json]]
  end

  ### Blocklist & Allowlist ###

  # Always allow requests from localhost (for development/testing)
  Rack::Attack.safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  # Block suspicious IPs
  # Add IPs to blocklist dynamically in production:
  # Rack::Attack::Allow2Ban.filter("logins/ip-#{req.ip}", maxretry: 20, findtime: 1.hour, bantime: 24.hours) do
  #   req.path == '/api/v1/login' && req.post?
  # end
end

# Log blocked requests (development/staging)
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]
  if %i[throttle blocklist].include?(req.env['rack.attack.match_type'])
    Rails.logger.warn "[Rack::Attack][#{req.env['rack.attack.match_type']}] " \
                      "#{req.ip} #{req.request_method} #{req.fullpath} " \
                      "Throttle: #{req.env['rack.attack.matched']}"
  end
end
