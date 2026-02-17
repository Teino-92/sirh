FactoryBot.define do
  factory :training do
    association :organization

    title { "#{Faker::Educator.subject} Training" }
    description { Faker::Lorem.paragraph }
    training_type { :internal }
    duration_estimate { 60 }

    trait :external do
      training_type { :external }
      provider { Faker::Company.name }
      external_url { "https://example.com/training" }
    end

    trait :certification do
      training_type { :certification }
      duration_estimate { 480 }
    end

    trait :e_learning do
      training_type { :e_learning }
      external_url { "https://learning.example.com/course" }
    end

    trait :mentoring do
      training_type { :mentoring }
      duration_estimate { 120 }
    end

    trait :archived do
      archived_at { 1.month.ago }
    end
  end
end
