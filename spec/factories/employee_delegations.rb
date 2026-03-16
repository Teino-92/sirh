# frozen_string_literal: true

FactoryBot.define do
  factory :employee_delegation do
    association :organization
    association :delegator, factory: :employee, role: 'manager'
    association :delegatee, factory: :employee, role: 'hr'
    role      { 'manager' }
    starts_at { 1.hour.ago }
    ends_at   { 1.hour.from_now }
    active    { true }
  end
end
