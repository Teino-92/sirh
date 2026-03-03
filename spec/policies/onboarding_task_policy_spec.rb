# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTaskPolicy, type: :policy do
  let(:organization)  { create(:organization) }
  let(:hr)            { create(:employee, organization: organization, role: 'hr') }
  let(:manager)       { create(:employee, organization: organization, role: 'manager') }
  let(:employee)      { create(:employee, organization: organization) }
  let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
  let(:template)      { create(:onboarding_template, organization: organization) }

  let(:onboarding) do
    ActsAsTenant.with_tenant(organization) do
      create(:employee_onboarding,
             organization: organization,
             employee: employee,
             manager: manager,
             onboarding_template: template)
    end
  end

  let(:task) do
    ActsAsTenant.with_tenant(organization) do
      create(:onboarding_task,
             employee_onboarding: onboarding,
             organization: organization,
             status: 'pending',
             task_type: 'manual')
    end
  end

  subject { described_class }

  describe 'Scope' do
    before { task }

    let(:other_onboarding) do
      ActsAsTenant.with_tenant(organization) do
        other_emp = create(:employee, organization: organization)
        create(:employee_onboarding,
               organization: organization,
               employee: other_emp,
               manager: other_manager,
               onboarding_template: template)
      end
    end

    let(:other_task) do
      ActsAsTenant.with_tenant(organization) do
        create(:onboarding_task,
               employee_onboarding: other_onboarding,
               organization: organization,
               status: 'pending',
               task_type: 'manual')
      end
    end

    before { other_task }

    context 'as HR' do
      it 'returns all tasks in organization' do
        ActsAsTenant.with_tenant(organization) do
          resolved = OnboardingTaskPolicy::Scope.new(hr, OnboardingTask).resolve
          expect(resolved).to include(task, other_task)
        end
      end
    end

    context 'as manager' do
      it 'returns only tasks belonging to managed onboardings' do
        ActsAsTenant.with_tenant(organization) do
          resolved = OnboardingTaskPolicy::Scope.new(manager, OnboardingTask).resolve
          expect(resolved).to include(task)
          expect(resolved).not_to include(other_task)
        end
      end
    end

    context 'as employee' do
      it 'returns only tasks from own onboarding' do
        ActsAsTenant.with_tenant(organization) do
          resolved = OnboardingTaskPolicy::Scope.new(employee, OnboardingTask).resolve
          expect(resolved).to include(task)
          expect(resolved).not_to include(other_task)
        end
      end
    end
  end

  permissions :update? do
    it 'permits HR' do
      expect(subject).to permit(hr, task)
    end

    it 'permits the assigned manager' do
      expect(subject).to permit(manager, task)
    end

    it 'denies another manager' do
      expect(subject).not_to permit(other_manager, task)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, task)
    end
  end
end
