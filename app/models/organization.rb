# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :employees, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :onboarding_templates, dependent: :destroy
  has_many :onboardings, dependent: :destroy

  validates :name, presence: true
  validate :safe_calendar_webhook_url

  # Initialize settings if nil
  after_initialize :ensure_settings

  # Default settings for French labor law
  def default_settings
    {
      work_week_hours: 35,
      cp_acquisition_rate: 2.5, # days per month
      cp_expiry_month: 5, # May
      cp_expiry_day: 31,
      rtt_enabled: true,
      overtime_threshold: 35, # hours per week
      max_daily_hours: 10, # French legal limit
      min_consecutive_leave_days: 10 # 2 weeks minimum
    }
  end

  def work_week_hours
    settings.fetch('work_week_hours', default_settings[:work_week_hours])
  end

  def rtt_enabled?
    settings.fetch('rtt_enabled', default_settings[:rtt_enabled])
  end

  def group_policies
    settings.fetch('group_policies', {
      'manager_can_approve_leave' => true,
      'auto_approve_leave_by_role' => {}
    })
  end

  private

  def ensure_settings
    self.settings ||= {}
  end

  # Prevent SSRF: only allow public HTTP/HTTPS URLs.
  # Blocks internal/loopback/link-local addresses and non-HTTP schemes.
  BLOCKED_IP_RANGES = [
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.168.0.0/16'),
    IPAddr.new('127.0.0.0/8'),
    IPAddr.new('169.254.0.0/16'), # link-local / AWS metadata
    IPAddr.new('::1/128'),
    IPAddr.new('fc00::/7')
  ].freeze

  def safe_calendar_webhook_url
    url = settings&.dig('calendar_webhook_url')
    return if url.blank?

    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      errors.add(:base, 'URL du webhook invalide')
      return
    end

    unless %w[http https].include?(uri.scheme)
      errors.add(:base, 'Le webhook doit utiliser HTTP ou HTTPS')
      return
    end

    if uri.host.blank?
      errors.add(:base, 'URL du webhook invalide (hôte manquant)')
      return
    end

    begin
      resolved = IPAddr.new(Resolv.getaddress(uri.host))
      if BLOCKED_IP_RANGES.any? { |range| range.include?(resolved) }
        errors.add(:base, 'URL du webhook non autorisée')
      end
    rescue Resolv::ResolvError, IPAddr::InvalidAddressError
      # Unknown host or unresolvable — block it to be safe
      errors.add(:base, 'Hôte du webhook inaccessible ou invalide')
    end
  end
end
