# frozen_string_literal: true

class TimeEntry < ApplicationRecord
  include JsonbValidatable

  acts_as_tenant :organization

  belongs_to :employee
  belongs_to :validated_by, class_name: 'Employee', optional: true
  belongs_to :rejected_by, class_name: 'Employee', optional: true

  validates :clock_in, presence: true
  validate :clock_out_after_clock_in
  validate :no_overlapping_entries
  validate :max_daily_hours
  validate :employee_belongs_to_same_organization
  validate :validators_belong_to_same_organization
  validate :period_not_locked, on: %i[create update]

  validates_jsonb_keys :location,
    allowed: %i[latitude longitude accuracy address],
    types: { latitude: Numeric, longitude: Numeric, accuracy: Numeric }

  before_save :calculate_duration
  after_save :check_rtt_accrual

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_date, ->(date) { where('DATE(clock_in) = ?', date) }
  scope :for_date_range, ->(start_date, end_date) do
    where('DATE(clock_in) BETWEEN ? AND ?', start_date, end_date)
  end
  scope :active, -> { where(clock_out: nil) }
  scope :completed, -> { where.not(clock_out: nil) }
  scope :this_week, -> { where('clock_in >= ?', Date.current.beginning_of_week) }
  scope :this_month, -> { where('clock_in >= ?', Date.current.beginning_of_month) }
  scope :validated, -> { where.not(validated_at: nil) }
  scope :rejected, -> { where.not(rejected_at: nil) }
  scope :pending_validation, -> { completed.where(validated_at: nil, rejected_at: nil) }
  scope :validated_this_week, -> { validated.where('validated_at >= ?', Date.current.beginning_of_week) }

  def clock_out!(time: Time.current, location: nil)
    update!(
      clock_out: time,
      location: location.present? ? location : self.location
    )
  end

  def active?
    clock_out.nil?
  end

  def completed?
    clock_out.present?
  end

  def hours_worked
    return 0 unless completed?
    return 0 if duration_minutes.nil?

    net = duration_minutes - break_duration_minutes.to_i
    [net, 0].max / 60.0
  end

  def overtime?
    return false unless completed?

    hours_worked > 7 # Standard daily hours
  end

  def worked_date
    clock_in.to_date
  end

  def validated?
    validated_at.present?
  end

  def rejected?
    rejected_at.present?
  end

  # Check if the employee clocked in late based on their schedule
  def late?
    return false unless clock_in.present?

    # Get the employee's weekly schedule for this date
    week_start = worked_date.beginning_of_week
    weekly_plan = employee.weekly_schedule_plans.find_by(week_start_date: week_start)

    return false unless weekly_plan

    # Get the expected start time for this day
    day_name = worked_date.strftime('%A').downcase
    expected_hours = weekly_plan.schedule_pattern&.dig(day_name)

    return false if expected_hours.blank? || expected_hours == 'off'

    # Parse the expected start time (format: "09:00-17:00")
    expected_start_time = expected_hours.split('-').first&.strip
    return false unless expected_start_time

    # Parse hours and minutes
    expected_hour, expected_minute = expected_start_time.split(':').map(&:to_i)

    # Create a Time object for the expected start time on the same date
    expected_start = clock_in.change(hour: expected_hour, min: expected_minute, sec: 0)

    # Consider late if more than 5 minutes after expected start time
    clock_in > (expected_start + 5.minutes)
  end

  def validate!(validator:)
    return false unless completed?
    return false if validated? || rejected?

    update!(
      validated_at: Time.current,
      validated_by: validator
    )
  end

  def reject!(rejector:, reason:)
    return false unless completed?
    return false if validated? || rejected?

    update!(
      rejected_at: Time.current,
      rejected_by: rejector,
      rejection_reason: reason
    )
  end

  private

  def calculate_duration
    return unless clock_out.present?

    self.duration_minutes = ((clock_out - clock_in) / 60).to_i
  end

  def clock_out_after_clock_in
    return if clock_out.blank?

    if clock_out <= clock_in
      errors.add(:clock_out, 'must be after clock in time')
    end
  end

  def no_overlapping_entries
    overlapping = employee.time_entries
                          .where.not(id: id)
                          .where('clock_in < ? AND (clock_out IS NULL OR clock_out > ?)',
                                 clock_out || Time.current, clock_in)

    if overlapping.exists?
      errors.add(:base, 'Overlapping time entry detected')
    end
  end

  def max_daily_hours
    return unless clock_out.present?

    if hours_worked > 10 # French legal limit
      errors.add(:base, 'Cannot exceed 10 hours per day (French legal limit)')
    end
  end

  def check_rtt_accrual
    # Trigger RTT calculation if entry is completed
    # This will be handled by a background job in production
    return unless saved_change_to_clock_out? && completed?

    TimeTracking::Services::RttAccrualService.new(employee).calculate_and_accrue_weekly
  end

  def employee_belongs_to_same_organization
    return unless employee && organization_id

    if employee.organization_id != organization_id
      errors.add(:employee, 'must belong to the same organization')
    end
  end

  def period_not_locked
    return unless clock_in.present? && organization_id.present?

    if PayrollPeriod.locked?(organization_id, clock_in.to_date)
      errors.add(:base, "La période #{clock_in.to_date.strftime('%B %Y')} est clôturée.")
    end
  end

  def validators_belong_to_same_organization
    if validated_by.present? && validated_by.organization_id != organization_id
      errors.add(:validated_by, 'must belong to the same organization')
    end

    if rejected_by.present? && rejected_by.organization_id != organization_id
      errors.add(:rejected_by, 'must belong to the same organization')
    end
  end
end
