FactoryBot.define do
  factory :action_item do
    association :one_on_one
    association :responsible, factory: :employee

    description { Faker::Lorem.sentence }
    deadline { 2.weeks.from_now.to_date }
    status { :pending }
    responsible_type { :employee }

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      completed_at { 1.day.ago.to_date }
      completion_notes { Faker::Lorem.paragraph }
    end

    trait :overdue do
      status { :pending }
      deadline { 1.week.ago.to_date }
    end

    trait :manager_responsible do
      responsible_type { :manager }
    end
  end
end
