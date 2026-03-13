# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeOnboardingPolicy, type: :policy do
  let(:organization)   { create(:organization) }
  let(:hr)             { create(:employee, organization: organization, role: 'hr') }
  let(:manager)        { create(:employee, organization: organization, role: 'manager') }
  let(:employee)       { create(:employee, organization: organization) }
  let(:other_manager)  { create(:employee, organization: organization, role: 'manager') }
  let(:other_employee) { create(:employee, organization: organization) }
  let(:template)       { create(:onboarding_template, organization: organization) }

  let(:onboarding) do
    ActsAsTenant.with_tenant(organization) do
      create(:employee_onboarding,
             organization: organization,
             employee: employee,
             manager: manager,
             onboarding_template: template)
    end
  end

  subject { described_class }

  describe 'Scope' do
    before { onboarding }

    let(:other_onboarding) do
      ActsAsTenant.with_tenant(organization) do
        create(:employee_onboarding,
               organization: organization,
               employee: other_employee,
               manager: other_manager,
               onboarding_template: template)
      end
    end

    before { other_onboarding }

    context 'as HR' do
      it 'returns all onboardings in organization' do
        ActsAsTenant.with_tenant(organization) do
          resolved = EmployeeOnboardingPolicy::Scope.new(hr, EmployeeOnboarding).resolve
          expect(resolved).to include(onboarding, other_onboarding)
        end
      end
    end

    context 'as manager' do
      it 'returns onboardings managed by or belonging to the manager' do
        ActsAsTenant.with_tenant(organization) do
          resolved = EmployeeOnboardingPolicy::Scope.new(manager, EmployeeOnboarding).resolve
          expect(resolved).to include(onboarding)
          expect(resolved).not_to include(other_onboarding)
        end
      end
    end

    context 'as employee' do
      it 'returns only own onboarding' do
        ActsAsTenant.with_tenant(organization) do
          resolved = EmployeeOnboardingPolicy::Scope.new(employee, EmployeeOnboarding).resolve
          expect(resolved).to include(onboarding)
          expect(resolved).not_to include(other_onboarding)
        end
      end
    end
  end

  permissions :index? do
    it 'permits HR' do
      expect(subject).to permit(hr, EmployeeOnboarding.new)
    end

    it 'permits manager' do
      expect(subject).to permit(manager, EmployeeOnboarding.new)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, EmployeeOnboarding.new)
    end
  end

  permissions :create? do
    it 'permits HR' do
      expect(subject).to permit(hr, EmployeeOnboarding.new)
    end

    context 'on Manager OS plan' do
      let(:organization) { create(:organization, plan: 'manager_os') }

      it 'permits manager' do
        expect(subject).to permit(manager, EmployeeOnboarding.new)
      end
    end

    context 'on SIRH plan' do
      it 'denies manager' do
        expect(subject).not_to permit(manager, EmployeeOnboarding.new)
      end
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, EmployeeOnboarding.new)
    end
  end

  permissions :show? do
    it 'permits HR' do
      expect(subject).to permit(hr, onboarding)
    end

    it 'permits the assigned manager' do
      expect(subject).to permit(manager, onboarding)
    end

    it 'permits the employee themselves' do
      expect(subject).to permit(employee, onboarding)
    end

    it 'denies another manager' do
      expect(subject).not_to permit(other_manager, onboarding)
    end
  end

  permissions :update? do
    it 'permits HR' do
      expect(subject).to permit(hr, onboarding)
    end

    it 'permits the assigned manager' do
      expect(subject).to permit(manager, onboarding)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, onboarding)
    end

    it 'denies another manager' do
      expect(subject).not_to permit(other_manager, onboarding)
    end
  end

  permissions :destroy? do
    it 'permits HR' do
      expect(subject).to permit(hr, onboarding)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, onboarding)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, onboarding)
    end
  end
end
