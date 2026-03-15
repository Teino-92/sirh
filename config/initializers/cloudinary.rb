# frozen_string_literal: true

Cloudinary.config do |config|
  config.cloud_name = ENV.fetch('CLOUDINARY_CLOUD_NAME', 'dv7rhtlg8')
  config.api_key    = ENV['CLOUDINARY_API_KEY']
  config.api_secret = ENV['CLOUDINARY_API_SECRET']
  config.secure     = true
end
