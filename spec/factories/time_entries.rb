# frozen_string_literal: true

FactoryBot.define do
  factory :time_entry do
    employee
    organization { employee.organization }
    clock_in { 2.hours.ago }
    clock_out { 1.hour.ago }
    duration_minutes { 60 }
    location { 'Office' }

    trait :active do
      clock_out { nil }
      duration_minutes { 0 }
    end

    trait :full_day do
      clock_in { Time.current.change(hour: 9, min: 0) }
      clock_out { Time.current.change(hour: 18, min: 0) }
      duration_minutes { 540 }
    end

    trait :overtime do
      clock_in { Time.current.change(hour: 8, min: 0) }
      clock_out { Time.current.change(hour: 20, min: 0) }
      duration_minutes { 720 }
    end

    trait :validated do
      validated_at { 1.hour.ago }
      validated_by { association :employee, :manager, organization: organization }
    end

    trait :rejected do
      rejected_at { 1.hour.ago }
      rejected_by { association :employee, :manager, organization: organization }
      rejection_reason { 'Invalid time entry' }
    end

    trait :this_week do
      clock_in { Date.current.beginning_of_week.to_time + 1.day + 9.hours }
      clock_out { Date.current.beginning_of_week.to_time + 1.day + 18.hours }
      duration_minutes { 540 }
    end

    trait :last_week do
      clock_in { 1.week.ago.beginning_of_week.to_time + 1.day + 9.hours }
      clock_out { 1.week.ago.beginning_of_week.to_time + 1.day + 18.hours }
      duration_minutes { 540 }
    end
  end
end
