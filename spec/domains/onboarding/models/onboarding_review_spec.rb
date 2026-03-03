# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingReview, type: :model do
  let(:organization) { create(:organization) }
  let(:template)     { ActsAsTenant.with_tenant(organization) { create(:onboarding_template, organization: organization) } }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization) }
  let(:onboarding) do
    ActsAsTenant.with_tenant(organization) do
      create(:employee_onboarding,
             organization: organization,
             employee: employee,
             manager: manager,
             onboarding_template: template)
    end
  end

  subject do
    ActsAsTenant.with_tenant(organization) do
      build(:onboarding_review,
            employee_onboarding: onboarding,
            organization: organization)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      ActsAsTenant.with_tenant(organization) { expect(subject).to be_valid }
    end

    it 'rejects invalid reviewer_type' do
      subject.reviewer_type = 'ceo'
      ActsAsTenant.with_tenant(organization) { expect(subject).not_to be_valid }
    end

    it 'rejects invalid review_day' do
      subject.review_day = 45
      ActsAsTenant.with_tenant(organization) { expect(subject).not_to be_valid }
    end

    it 'enforces uniqueness per onboarding + reviewer_type + review_day' do
      ActsAsTenant.with_tenant(organization) do
        create(:onboarding_review,
               employee_onboarding: onboarding,
               organization: organization,
               reviewer_type: 'manager',
               review_day: 30)
        duplicate = build(:onboarding_review,
                          employee_onboarding: onboarding,
                          organization: organization,
                          reviewer_type: 'manager',
                          review_day: 30)
        expect(duplicate).not_to be_valid
      end
    end
  end

  describe '#employee_confidence_score' do
    it 'returns confidence from employee_feedback_json' do
      subject.employee_feedback_json = { 'confidence' => 4 }
      expect(subject.employee_confidence_score).to eq(4)
    end

    it 'returns nil when key absent' do
      subject.employee_feedback_json = {}
      expect(subject.employee_confidence_score).to be_nil
    end
  end

  describe '#manager_integration_level' do
    it 'returns integration_level from manager_feedback_json' do
      subject.manager_feedback_json = { 'integration_level' => 3 }
      expect(subject.manager_integration_level).to eq(3)
    end

    it 'returns nil when key absent' do
      subject.manager_feedback_json = {}
      expect(subject.manager_integration_level).to be_nil
    end
  end
end
