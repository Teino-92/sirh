FactoryBot.define do
  factory :one_on_one do
    association :organization
    association :manager, factory: :employee
    association :employee, factory: :employee

    scheduled_at { 1.week.from_now }
    status { :scheduled }
    agenda { Faker::Lorem.sentence }

    trait :completed do
      status { :completed }
      completed_at { 1.day.ago }
      notes { Faker::Lorem.paragraph }
    end

    trait :upcoming do
      scheduled_at { 2.days.from_now }
      status { :scheduled }
    end

    trait :past do
      status { :completed }
      scheduled_at { 1.month.ago }
      completed_at { 1.month.ago }
    end
  end
end
