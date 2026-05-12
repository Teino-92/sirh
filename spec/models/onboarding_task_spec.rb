# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTask, type: :model do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, :manager, organization: org) }
  let(:employee) { create(:employee, organization: org) }
  let(:onboarding) do
    ActsAsTenant.with_tenant(org) do
      create(:employee_onboarding, organization: org, employee: employee, manager: manager)
    end
  end

  subject(:task) do
    ActsAsTenant.with_tenant(org) do
      build(:onboarding_task, organization: org, employee_onboarding: onboarding,
            assigned_to_role: 'employee', status: 'pending')
    end
  end

  describe '#mark_done!' do
    it 'transitions pending → done' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.mark_done!(employee)
        expect(task.reload.status).to eq('done')
        expect(task.completed_by_id).to eq(employee.id)
        expect(task.completed_at).to be_present
      end
    end

    it 'raises if already completed' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'completed')
        expect { task.mark_done!(employee) }.to raise_error(OnboardingTask::InvalidTransitionError, /déjà complétée/)
      end
    end

    it 'raises if assigned_to_role is not employee' do
      ActsAsTenant.with_tenant(org) do
        manager_task = build(:onboarding_task, organization: org,
                             employee_onboarding: onboarding, assigned_to_role: 'manager')
        manager_task.save!
        expect { manager_task.mark_done!(employee) }.to raise_error(OnboardingTask::InvalidTransitionError, /assigned_to_role/)
      end
    end
  end

  describe '#validate!' do
    it 'transitions done → completed' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'done')
        task.validate!(manager)
        expect(task.reload.status).to eq('completed')
        expect(task.validated_at).to be_present
        expect(task.validated_by_id).to eq(manager.id)
      end
    end

    it 'raises if not done' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        expect { task.validate!(manager) }.to raise_error(OnboardingTask::InvalidTransitionError, /doit être done/)
      end
    end
  end

  describe '#complete!' do
    it 'transitions pending → completed directly (manager/hr path)' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.complete!(completed_by: manager)
        expect(task.reload.status).to eq('completed')
        expect(task.completed_by_id).to eq(manager.id)
        expect(task.completed_at).to be_present
      end
    end

    it 'is idempotent — does nothing if already completed' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'completed', completed_at: 1.hour.ago)
        original_completed_at = task.completed_at
        task.complete!(completed_by: manager)
        expect(task.reload.completed_at.to_i).to eq(original_completed_at.to_i)
      end
    end
  end
end
