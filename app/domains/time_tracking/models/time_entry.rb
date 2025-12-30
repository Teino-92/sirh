# frozen_string_literal: true

class TimeEntry < ApplicationRecord
  belongs_to :employee

  validates :clock_in, presence: true
  validate :clock_out_after_clock_in
  validate :no_overlapping_entries
  validate :max_daily_hours

  before_save :calculate_duration
  # after_save :check_rtt_accrual # Disabled temporarily for seeding - will be re-enabled with proper autoloading

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }
  scope :for_date, ->(date) { where('DATE(clock_in) = ?', date) }
  scope :for_date_range, ->(start_date, end_date) do
    where('DATE(clock_in) BETWEEN ? AND ?', start_date, end_date)
  end
  scope :active, -> { where(clock_out: nil) }
  scope :completed, -> { where.not(clock_out: nil) }
  scope :this_week, -> { where('clock_in >= ?', Date.current.beginning_of_week) }
  scope :this_month, -> { where('clock_in >= ?', Date.current.beginning_of_month) }

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

    duration_minutes / 60.0
  end

  def overtime?
    return false unless completed?

    hours_worked > 7 # Standard daily hours
  end

  def worked_date
    clock_in.to_date
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
end
