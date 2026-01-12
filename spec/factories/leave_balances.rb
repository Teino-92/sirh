# frozen_string_literal: true

FactoryBot.define do
  factory :leave_balance do
    employee
    organization { employee.organization }
    leave_type { 'CP' }
    balance { 15.0 }
    accrued_this_year { 10.0 }
    used_this_year { 5.0 }
    expires_at { Date.new(Date.current.year + 1, 5, 31) }

    trait :cp do
      leave_type { 'CP' }
    end

    trait :rtt do
      leave_type { 'RTT' }
      expires_at { nil }
    end

    trait :full_balance do
      balance { 30.0 }
      accrued_this_year { 30.0 }
      used_this_year { 0.0 }
    end

    trait :low_balance do
      balance { 2.5 }
      accrued_this_year { 10.0 }
      used_this_year { 7.5 }
    end

    trait :expired do
      expires_at { 1.month.ago.to_date }
    end

    trait :expiring_soon do
      expires_at { 2.months.from_now.to_date }
    end
  end
end
