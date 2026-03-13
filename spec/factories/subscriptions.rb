# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    organization
    stripe_customer_id      { "cus_#{SecureRandom.hex(8)}" }
    stripe_subscription_id  { "sub_#{SecureRandom.hex(8)}" }
    plan                    { "sirh_essential" }
    status                  { "active" }
    current_period_end      { 1.month.from_now }
    cancel_at_period_end    { false }

    # ── Status traits ────────────────────────────────────────────────────────
    trait :active do
      status { "active" }
    end

    trait :trialing do
      status { "trialing" }
    end

    trait :past_due do
      status { "past_due" }
    end

    trait :canceled do
      status { "canceled" }
    end

    trait :incomplete do
      status       { "incomplete" }
      # Une sub incomplete n'a pas encore de stripe_subscription_id confirmé
      stripe_subscription_id { nil }
    end

    # ── Plan traits ──────────────────────────────────────────────────────────
    trait :manager_os do
      plan { "manager_os" }
    end

    trait :sirh_essential do
      plan { "sirh_essential" }
    end

    trait :sirh_pro do
      plan { "sirh_pro" }
    end

    # ── Engagement annuel ────────────────────────────────────────────────────
    trait :committed do
      commitment_end_at { 10.months.from_now }
    end
  end
end
