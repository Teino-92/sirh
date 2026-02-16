FactoryBot.define do
  factory :objective do
    association :organization
    association :manager, factory: :employee
    association :created_by, factory: :employee
    association :owner, factory: :employee

    title { "Q#{rand(1..4)} Objective - #{Faker::Lorem.words(number: 3).join(' ')}" }
    description { Faker::Lorem.paragraph }
    status { :in_progress }
    priority { :medium }
    deadline { 3.months.from_now.to_date }

    trait :draft do
      status { :draft }
    end

    trait :completed do
      status { :completed }
      completed_at { 1.week.ago }
    end

    trait :overdue do
      status { :in_progress }
      deadline { 1.week.ago.to_date }
    end

    trait :high_priority do
      priority { :high }
    end
  end
end
