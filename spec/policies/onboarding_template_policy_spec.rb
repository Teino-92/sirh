# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTemplatePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr)           { create(:employee, organization: organization, role: 'hr') }
  let(:admin)        { create(:employee, organization: organization, role: 'admin') }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization) }

  let(:template) do
    ActsAsTenant.with_tenant(organization) do
      create(:onboarding_template, organization: organization)
    end
  end

  subject { described_class }

  describe 'Scope' do
    before { template }

    it 'restricts to current organization active templates' do
      ActsAsTenant.with_tenant(organization) do
        resolved = OnboardingTemplatePolicy::Scope.new(hr, OnboardingTemplate).resolve
        expect(resolved).to include(template)
      end
    end

    it 'does not include templates from another org' do
      other_org = create(:organization)
      other_template = ActsAsTenant.with_tenant(other_org) do
        create(:onboarding_template, organization: other_org)
      end

      ActsAsTenant.with_tenant(organization) do
        resolved = OnboardingTemplatePolicy::Scope.new(hr, OnboardingTemplate).resolve
        expect(resolved).not_to include(other_template)
      end
    end
  end

  permissions :index?, :show? do
    it 'permits HR' do
      expect(subject).to permit(hr, template)
    end

    it 'permits admin' do
      expect(subject).to permit(admin, template)
    end

    it 'permits manager (read-only access)' do
      expect(subject).to permit(manager, template)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, template)
    end
  end

  permissions :create?, :update?, :destroy? do
    it 'permits HR' do
      expect(subject).to permit(hr, template)
    end

    it 'permits admin' do
      expect(subject).to permit(admin, template)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, template)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, template)
    end
  end
end
