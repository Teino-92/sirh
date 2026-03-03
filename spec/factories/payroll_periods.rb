# frozen_string_literal: true

FactoryBot.define do
  factory :payroll_period do
    organization
    association :locked_by, factory: :employee
    period    { Date.current.beginning_of_month - 1.month }
    locked_at { 1.day.ago }
  end
end
