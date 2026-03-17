# frozen_string_literal: true

class Organization < ApplicationRecord
  include JsonbValidatable

  # Settings is an open-ended hash (extensible by design).
  # We only type-check the well-known keys; unknown keys are tolerated.
  validates_jsonb_keys :settings,
    types: {
      work_week_hours: Numeric, cp_acquisition_rate: Numeric,
      cp_expiry_month: Integer, cp_expiry_day: Integer
    }

  has_many :employees, dependent: :destroy
  has_one  :subscription, dependent: :destroy
  has_many :business_rules, dependent: :destroy
  has_many :outgoing_merge_invitations, class_name: 'OrgMergeInvitation', foreign_key: :source_organization_id, dependent: :destroy
  has_many :incoming_merge_invitations, class_name: 'OrgMergeInvitation', foreign_key: :target_organization_id, dependent: :destroy
  belongs_to :merged_into, class_name: 'Organization', optional: true
  has_many :approval_steps, dependent: :destroy
  has_many :rule_executions, dependent: :destroy
  has_many :employee_delegations, dependent: :destroy
  has_many :payroll_periods, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :onboarding_templates, dependent: :destroy
  has_many :employee_onboardings, dependent: :destroy, foreign_key: :organization_id
  has_many :objectives, dependent: :destroy
  has_many :one_on_ones, dependent: :destroy
  has_many :trainings, dependent: :destroy
  has_many :training_assignments, through: :trainings

  PLANS = %w[manager_os sirh].freeze
  BILLING_MODELS = %w[per_team per_employee].freeze

  validates :name, presence: true
  validates :plan, inclusion: { in: PLANS }
  validates :billing_model, inclusion: { in: BILLING_MODELS }
  validate :safe_calendar_webhook_url
  validate :safe_payroll_webhook_url
  validate :valid_legal_department

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

  def payroll_webhook_url
    settings['payroll_webhook_url'].presence
  end

  def payroll_webhook_secret
    settings['payroll_webhook_secret'].presence
  end

  # Plan helpers
  def manager_os?
    plan == "manager_os"
  end

  # Trial helpers
  def trial_expired?
    trial_ends_at.present? && trial_ends_at < Time.current
  end

  def trial_active?
    trial_ends_at.present? && trial_ends_at >= Time.current
  end

  def trial_days_remaining
    return nil if trial_ends_at.blank?
    return 0   if trial_expired?
    (trial_ends_at.to_date - Date.current).to_i
  end

  def trial_ends_in_days?(days)
    trial_ends_at.present? && trial_ends_at.to_date == Date.current + days.days
  end

  def sirh?
    plan == "sirh"
  end

  def merged?
    status == 'merged'
  end

  def upgrade_to_sirh!
    with_lock do
      return true if sirh?
      update!(plan: "sirh", billing_model: "per_employee", plan_started_at: Time.current)
    end
  end

  # Returns :alsace_moselle if the org is registered in depts 57, 67 or 68, nil otherwise.
  # Configurable via settings['legal_department'] (e.g. "67").
  def legal_region
    dept = settings['legal_department'].to_s.strip
    return :alsace_moselle if FrenchCalendar::ALSACE_MOSELLE_DEPARTMENTS.include?(dept)
    nil
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

  VALID_DEPARTMENTS = (
    (1..95).map { |i| i.to_s.rjust(2, '0') } +
    %w[971 972 973 974 975 976]
  ).freeze

  def valid_legal_department
    dept = settings&.dig('legal_department').to_s.strip
    return if dept.blank?
    unless VALID_DEPARTMENTS.include?(dept)
      errors.add(:base, "Département siège social invalide — utilisez le format 01–95 ou 971–976")
    end
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

  def safe_payroll_webhook_url
    url = settings&.dig('payroll_webhook_url')
    return if url.blank?

    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      errors.add(:base, 'URL du webhook Silae invalide')
      return
    end

    unless %w[http https].include?(uri.scheme)
      errors.add(:base, 'Le webhook Silae doit utiliser HTTP ou HTTPS')
      return
    end

    if uri.host.blank?
      errors.add(:base, 'URL du webhook Silae invalide (hôte manquant)')
      return
    end

    begin
      resolved = IPAddr.new(Resolv.getaddress(uri.host))
      if BLOCKED_IP_RANGES.any? { |range| range.include?(resolved) }
        errors.add(:base, 'URL du webhook Silae non autorisée')
      end
    rescue Resolv::ResolvError, IPAddr::InvalidAddressError
      errors.add(:base, 'Hôte du webhook Silae inaccessible ou invalide')
    end
  end
end
