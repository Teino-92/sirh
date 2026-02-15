# frozen_string_literal: true

FactoryBot.define do
  factory :leave_request do
    employee
    organization { employee.organization }
    leave_type { 'CP' }
    start_date { 1.week.from_now.to_date }
    end_date { 2.weeks.from_now.to_date }
    days_count { 5.0 }
    status { 'pending' }
    reason { 'Summer vacation' }

    trait :pending do
      status { 'pending' }
    end

    trait :approved do
      status { 'approved' }
      approved_by { association :employee, :manager, organization: organization }
      approved_at { 1.day.ago }
    end

    trait :auto_approved do
      status { 'auto_approved' }
      approved_at { 1.day.ago }
    end

    trait :rejected do
      status { 'rejected' }
      approved_by { association :employee, :manager, organization: organization }
      approved_at { 1.day.ago }
      rejection_reason { 'Team coverage issue' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    trait :rtt do
      leave_type { 'RTT' }
      days_count { 1.0 }
      start_date { 3.days.from_now.to_date }
      end_date { 3.days.from_now.to_date }
    end

    trait :sick_leave do
      leave_type { 'Maladie' }
      days_count { 3.0 }
      start_date { Date.current }
      end_date { 2.days.from_now.to_date }
    end

    trait :short_leave do
      days_count { 1.0 }
      start_date { 3.days.from_now.to_date }
      end_date { 3.days.from_now.to_date }
    end

    trait :long_leave do
      days_count { 15.0 }
      start_date { 1.month.from_now.to_date }
      end_date { (1.month.from_now + 14.days).to_date }
    end

    trait :past do
      start_date { 2.weeks.ago.to_date }
      end_date { 1.week.ago.to_date }
      days_count { 5.0 }
    end

    trait :ongoing do
      start_date { 2.days.ago.to_date }
      end_date { 3.days.from_now.to_date }
      days_count { 5.0 }
    end
  end
end
