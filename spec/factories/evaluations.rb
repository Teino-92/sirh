FactoryBot.define do
  factory :evaluation do
    association :organization
    association :employee, factory: :employee
    association :manager, factory: :employee
    association :created_by, factory: :employee

    period_start { 1.year.ago.beginning_of_year.to_date }
    period_end { 1.year.ago.end_of_year.to_date }
    status { :draft }

    after(:build) do |evaluation, _evaluator|
      evaluation.organization ||= evaluation.employee&.organization
    end

    trait :employee_review_pending do
      status { :employee_review_pending }
    end

    trait :manager_review_pending do
      status { :manager_review_pending }
      self_review { Faker::Lorem.paragraph }
    end

    trait :completed do
      status { :completed }
      self_review { Faker::Lorem.paragraph }
      manager_review { Faker::Lorem.paragraph }
      score { 3 }
      completed_at { 1.month.ago.to_date }
    end

    trait :with_objectives do
      after(:create) do |evaluation|
        objective = create(:objective,
          organization: evaluation.organization,
          manager: evaluation.manager,
          created_by: evaluation.manager,
          owner: evaluation.employee
        )
        evaluation.objectives << objective
      end
    end
  end
end
