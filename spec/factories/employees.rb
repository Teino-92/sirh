# frozen_string_literal: true

FactoryBot.define do
  factory :employee do
    organization
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { 'employee' }
    contract_type { 'CDI' }
    start_date { 1.year.ago.to_date }
    phone { Faker::PhoneNumber.phone_number }
    department { %w[Engineering Sales Marketing HR Finance].sample }
    job_title { Faker::Job.title }
    settings { { active: true } }

    trait :manager do
      role { 'manager' }
    end

    trait :hr do
      role { 'hr' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :inactive do
      settings { { active: false } }
    end

    trait :with_end_date do
      end_date { 1.month.from_now.to_date }
    end

    trait :cdd do
      contract_type { 'CDD' }
      end_date { 6.months.from_now.to_date }
    end

    trait :stage do
      contract_type { 'Stage' }
      end_date { 3.months.from_now.to_date }
    end

    trait :alternance do
      contract_type { 'Alternance' }
      end_date { 1.year.from_now.to_date }
    end

    trait :with_manager do
      manager { association :employee, :manager, organization: organization }
    end

    trait :recent_hire do
      start_date { 1.month.ago.to_date }
    end

    trait :long_tenure do
      start_date { 5.years.ago.to_date }
    end
  end
end
