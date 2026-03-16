# frozen_string_literal: true

FactoryBot.define do
  factory :business_rule do
    association :organization
    name        { "Règle test #{SecureRandom.hex(4)}" }
    trigger     { 'leave_request.submitted' }
    conditions  { [] }
    actions     { [{ 'type' => 'require_approval', 'role' => 'manager', 'order' => 1 }] }
    priority    { 0 }
    active      { true }
  end
end
