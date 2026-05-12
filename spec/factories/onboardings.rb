# frozen_string_literal: true

FactoryBot.define do
  factory :onboarding_template do
    association :organization

    name         { "Template #{Faker::Job.field}" }
    description  { Faker::Lorem.sentence }
    duration_days { 90 }
    active       { true }

    trait :inactive do
      active { false }
    end

    trait :short do
      duration_days { 30 }
    end
  end

  factory :onboarding_template_task do
    association :onboarding_template
    association :organization

    title            { Faker::Lorem.sentence(word_count: 4) }
    description      { Faker::Lorem.sentence }
    assigned_to_role { 'manager' }
    due_day_offset   { 7 }
    task_type        { 'manual' }
    position         { 0 }
    metadata         { {} }

    trait :objective_30 do
      task_type    { 'objective_30' }
      due_day_offset { 30 }
      metadata     { { 'title' => 'Objectif 30 jours' } }
    end

    trait :objective_60 do
      task_type    { 'objective_60' }
      due_day_offset { 60 }
      metadata     { { 'title' => 'Objectif 60 jours' } }
    end

    trait :objective_90 do
      task_type    { 'objective_90' }
      due_day_offset { 90 }
      metadata     { { 'title' => 'Objectif 90 jours' } }
    end

    trait :training do
      task_type    { 'training' }
      due_day_offset { 14 }
      # metadata['training_id'] must be set per test with real Training id
    end

    trait :one_on_one do
      task_type    { 'one_on_one' }
      due_day_offset { 7 }
      metadata     { { 'title' => '1:1 de bienvenue' } }
    end
  end

  factory :employee_onboarding do
    association :organization
    association :employee, factory: :employee
    association :manager,  factory: [:employee, :manager]
    association :onboarding_template

    start_date { Date.current }
    end_date   { 90.days.from_now.to_date }
    status     { 'active' }
    progress_percentage_cache { 0 }
    integration_score_cache   { 0 }

    trait :completed do
      status { 'completed' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end

    trait :with_progress do
      progress_percentage_cache { 50 }
      integration_score_cache   { 45 }
    end
  end

  factory :onboarding_task do
    association :employee_onboarding
    association :organization

    title            { Faker::Lorem.sentence(word_count: 4) }
    assigned_to_role { 'manager' }
    due_date         { 7.days.from_now.to_date }
    status           { 'pending' }
    task_type        { 'manual' }
    metadata         { {} }

    trait :completed do
      status       { 'completed' }
      completed_at { Time.current }
    end

    trait :done do
      status           { 'done' }
      assigned_to_role { 'employee' }
      completed_at     { 1.day.ago }
      completed_by     { association(:employee, organization: organization) }
    end

    trait :employee_task do
      assigned_to_role { 'employee' }
    end

    trait :overdue do
      due_date { 7.days.ago.to_date }
    end

    trait :with_linked_objective do
      task_type { 'objective_30' }
      # metadata['linked_objective_id'] must be set per test
    end

    trait :with_linked_training do
      task_type { 'training' }
      # metadata['linked_training_assignment_id'] must be set per test
    end

    trait :with_linked_one_on_one do
      task_type { 'one_on_one' }
      # metadata['linked_one_on_one_id'] must be set per test
    end
  end

  factory :onboarding_review do
    association :employee_onboarding
    association :organization

    reviewer_type          { 'manager' }
    review_day             { 30 }
    employee_feedback_json { {} }
    manager_feedback_json  { {} }

    trait :manager_review do
      reviewer_type         { 'manager' }
      review_day            { 30 }
      manager_feedback_json { { 'integration_level' => 4 } }
    end

    trait :employee_review do
      reviewer_type          { 'employee' }
      review_day             { 30 }
      employee_feedback_json { { 'confidence' => 4 } }
    end

    trait :day_90 do
      review_day { 90 }
    end
  end
end
