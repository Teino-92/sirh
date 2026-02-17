FactoryBot.define do
  factory :training_assignment do
    association :training
    association :employee, factory: :employee
    association :assigned_by, factory: :employee

    status { :assigned }
    assigned_at { Date.current }

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      completed_at { 1.week.ago }
      completion_notes { Faker::Lorem.sentence }
    end

    trait :overdue do
      status { :assigned }
      deadline { 1.week.ago.to_date }
    end

    trait :with_deadline do
      deadline { 1.month.from_now.to_date }
    end
  end
end
