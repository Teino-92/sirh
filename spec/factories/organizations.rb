# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    name { Faker::Company.name }
    settings do
      {
        work_week_hours: 35,
        cp_acquisition_rate: 2.5,
        cp_expiry_month: 5,
        cp_expiry_day: 31,
        rtt_enabled: true,
        overtime_threshold: 35,
        max_daily_hours: 10,
        min_consecutive_leave_days: 10
      }
    end

    trait :with_rtt_disabled do
      settings do
        {
          work_week_hours: 35,
          cp_acquisition_rate: 2.5,
          cp_expiry_month: 5,
          cp_expiry_day: 31,
          rtt_enabled: false,
          overtime_threshold: 35,
          max_daily_hours: 10,
          min_consecutive_leave_days: 10
        }
      end
    end

    trait :with_39_hour_week do
      settings do
        {
          work_week_hours: 39,
          cp_acquisition_rate: 2.5,
          cp_expiry_month: 5,
          cp_expiry_day: 31,
          rtt_enabled: true,
          overtime_threshold: 35,
          max_daily_hours: 10,
          min_consecutive_leave_days: 10
        }
      end
    end
  end
end
