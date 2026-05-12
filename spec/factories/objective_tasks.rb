# frozen_string_literal: true

FactoryBot.define do
  factory :objective_task do
    association :organization
    association :objective
    association :assigned_to, factory: :employee

    title       { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    deadline    { 2.weeks.from_now.to_date }
    status      { :todo }
    position    { 0 }

    trait :done do
      status       { :done }
      completed_at { 1.day.ago }
      association :completed_by, factory: :employee
    end

    trait :validated do
      status       { :validated }
      completed_at { 2.days.ago }
      validated_at { 1.day.ago }
      association :completed_by, factory: :employee
      association :validated_by, factory: :employee
    end
  end
end
