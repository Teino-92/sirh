# frozen_string_literal: true

class WeeklySchedulePlan < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :employee

  validates :week_start_date, :schedule_pattern, presence: true
  validates :week_start_date, uniqueness: { scope: :employee_id }
  validate :week_start_date_must_be_monday
  validate :employee_belongs_to_same_organization

  scope :for_week, ->(date) { where(week_start_date: date.beginning_of_week) }
  scope :upcoming, -> { where('week_start_date >= ?', Date.current.beginning_of_week).order(:week_start_date) }
  scope :past, -> { where('week_start_date < ?', Date.current.beginning_of_week).order(week_start_date: :desc) }

  def week_end_date
    week_start_date + 6.days
  end

  def current_week?
    week_start_date == Date.current.beginning_of_week
  end

  def past_week?
    week_start_date < Date.current.beginning_of_week
  end

  def future_week?
    week_start_date > Date.current.beginning_of_week
  end

  def hours_for_day(day_name)
    pattern = schedule_pattern[day_name.to_s.downcase]
    return 0 unless pattern
    return 0 if pattern == 'off'

    # Parse "09:00-17:00" format
    start_time, end_time = pattern.split('-')
    return 0 unless start_time && end_time

    start_hour, start_min = start_time.split(':').map(&:to_i)
    end_hour, end_min = end_time.split(':').map(&:to_i)

    ((end_hour * 60 + end_min) - (start_hour * 60 + start_min)) / 60.0
  end

  def total_weekly_hours
    %w[monday tuesday wednesday thursday friday saturday sunday].sum do |day|
      hours_for_day(day)
    end
  end

  private

  def week_start_date_must_be_monday
    return if week_start_date.blank?

    unless week_start_date.monday?
      errors.add(:week_start_date, 'doit être un lundi')
    end
  end

  def employee_belongs_to_same_organization
    return unless employee && organization_id

    if employee.organization_id != organization_id
      errors.add(:employee, 'must belong to the same organization')
    end
  end
end
