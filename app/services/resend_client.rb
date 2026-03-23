# frozen_string_literal: true

# Thin wrapper around the Resend transactional email API.
#
# Usage:
#   ResendClient.deliver(to: "user@example.com", subject: "Hello", html: "<p>Hi</p>")
#
# Returns the Faraday response object.
class ResendClient
  API_URL  = 'https://api.resend.com'
  FROM     = -> { "Izi-RH <noreply@#{ENV.fetch('SMTP_DOMAIN', 'izi-rh.com')}>" }

  def self.deliver(to:, subject:, html:, from: FROM.call)
    conn = Faraday.new(API_URL) do |f|
      f.request  :json
      f.response :json
      f.adapter  Faraday.default_adapter
    end

    response = conn.post('/emails') do |req|
      req.headers['Authorization'] = "Bearer #{ENV['RESEND_API_KEY']}"
      req.headers['Content-Type']  = 'application/json'
      req.body = { from: from, to: Array(to), subject: subject, html: html }
    end

    unless response.success?
      Rails.logger.error "[ResendClient] Email to #{to} failed: #{response.status} #{response.body}"
    end

    response
  end
end
