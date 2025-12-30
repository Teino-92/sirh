# frozen_string_literal: true

class WorkSchedule < ApplicationRecord
  belongs_to :employee

  validates :name, :weekly_hours, :schedule_pattern, presence: true
  validates :weekly_hours, numericality: { greater_than: 0, less_than_or_equal_to: 48 } # French legal max
  validates :employee_id, uniqueness: true

  # Standard schedule templates
  TEMPLATES = {
    'full_time_35h' => {
      name: '35h - Temps plein',
      weekly_hours: 35,
      schedule_pattern: {
        'monday' => '09:00-17:00',
        'tuesday' => '09:00-17:00',
        'wednesday' => '09:00-17:00',
        'thursday' => '09:00-17:00',
        'friday' => '09:00-17:00'
      }
    },
    'full_time_39h' => {
      name: '39h - Temps plein avec RTT',
      weekly_hours: 39,
      schedule_pattern: {
        'monday' => '09:00-18:00',
        'tuesday' => '09:00-18:00',
        'wednesday' => '09:00-18:00',
        'thursday' => '09:00-18:00',
        'friday' => '09:00-17:00'
      }
    },
    'part_time_24h' => {
      name: '24h - Temps partiel (3/5)',
      weekly_hours: 24,
      schedule_pattern: {
        'monday' => '09:00-17:00',
        'tuesday' => '09:00-17:00',
        'wednesday' => '09:00-17:00'
      }
    }
  }.freeze

  after_save :calculate_rtt_rate

  def self.create_from_template(employee, template_key)
    template = TEMPLATES[template_key]
    raise ArgumentError, "Unknown template: #{template_key}" unless template

    create!(
      employee: employee,
      name: template[:name],
      weekly_hours: template[:weekly_hours],
      schedule_pattern: template[:schedule_pattern]
    )
  end

  def full_time?
    weekly_hours >= 35
  end

  def part_time?
    weekly_hours < 35
  end

  def works_on?(day_name)
    schedule_pattern.key?(day_name.to_s.downcase)
  end

  def hours_for_day(day_name)
    pattern = schedule_pattern[day_name.to_s.downcase]
    return 0 unless pattern

    # Parse "09:00-17:00" format
    start_time, end_time = pattern.split('-')
    return 0 unless start_time && end_time

    start_hour, start_min = start_time.split(':').map(&:to_i)
    end_hour, end_min = end_time.split(':').map(&:to_i)

    ((end_hour * 60 + end_min) - (start_hour * 60 + start_min)) / 60.0
  end

  def daily_hours
    schedule_pattern.transform_values do |pattern|
      start_time, end_time = pattern.split('-')
      next 0 unless start_time && end_time

      start_hour, start_min = start_time.split(':').map(&:to_i)
      end_hour, end_min = end_time.split(':').map(&:to_i)

      ((end_hour * 60 + end_min) - (start_hour * 60 + start_min)) / 60.0
    end
  end

  def working_days
    schedule_pattern.keys
  end

  def rtt_eligible?
    weekly_hours > 35 && employee.organization.rtt_enabled?
  end

  private

  def calculate_rtt_rate
    return unless rtt_eligible?

    # Calculate RTT accrual rate based on hours over 35h
    overtime_hours = weekly_hours - 35
    # 1 RTT day = 7 hours of overtime
    rate = (overtime_hours / 7.0) * 4.33 # 4.33 weeks per month average

    update_column(:rtt_accrual_rate, rate)
  end
end
