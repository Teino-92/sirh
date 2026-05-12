# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTaskPolicy, type: :policy do
  let(:org)       { create(:organization) }
  let(:manager)   { create(:employee, :manager, organization: org) }
  let(:employee)  { create(:employee, organization: org) }
  let(:other_emp) { create(:employee, organization: org) }

  let(:onboarding) do
    ActsAsTenant.with_tenant(org) do
      create(:employee_onboarding, organization: org, employee: employee, manager: manager)
    end
  end

  let(:pending_emp_task) do
    ActsAsTenant.with_tenant(org) do
      create(:onboarding_task, :employee_task, organization: org,
             employee_onboarding: onboarding, status: 'pending')
    end
  end

  let(:done_emp_task) do
    ActsAsTenant.with_tenant(org) do
      create(:onboarding_task, :done, organization: org, employee_onboarding: onboarding)
    end
  end

  let(:completed_task) do
    ActsAsTenant.with_tenant(org) do
      create(:onboarding_task, :completed, organization: org, employee_onboarding: onboarding)
    end
  end

  describe 'manager permissions' do
    describe 'validate?' do
      it 'permits manager of onboarding when task is done' do
        policy = described_class.new(manager, done_emp_task)
        expect(policy.validate?).to be true
      end

      it 'denies when task is not done' do
        policy = described_class.new(manager, pending_emp_task)
        expect(policy.validate?).to be false
      end

      it 'denies employee' do
        policy = described_class.new(employee, done_emp_task)
        expect(policy.validate?).to be false
      end
    end

    describe 'update?' do
      it 'permits manager of onboarding' do
        policy = described_class.new(manager, pending_emp_task)
        expect(policy.update?).to be true
      end
    end
  end

  describe 'employee permissions' do
    describe 'mark_done?' do
      it 'permits assigned employee on pending task' do
        policy = described_class.new(employee, pending_emp_task)
        expect(policy.mark_done?).to be true
      end

      it 'denies if task not pending' do
        policy = described_class.new(employee, done_emp_task)
        expect(policy.mark_done?).to be false
      end

      it 'denies if assigned_to_role != employee' do
        manager_task = ActsAsTenant.with_tenant(org) do
          create(:onboarding_task, organization: org,
                 employee_onboarding: onboarding, assigned_to_role: 'manager', status: 'pending')
        end
        policy = described_class.new(employee, manager_task)
        expect(policy.mark_done?).to be false
      end

      it 'denies other employee' do
        policy = described_class.new(other_emp, pending_emp_task)
        expect(policy.mark_done?).to be false
      end
    end
  end
end
