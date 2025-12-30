# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :employees, dependent: :destroy

  validates :name, presence: true

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
end
