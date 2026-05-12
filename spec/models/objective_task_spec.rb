# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectiveTask, type: :model do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, :manager, organization: org) }
  let(:employee) { create(:employee, organization: org) }
  let(:objective) do
    ActsAsTenant.with_tenant(org) do
      create(:objective, organization: org, manager: manager, owner: employee, created_by: manager)
    end
  end

  subject(:task) do
    ActsAsTenant.with_tenant(org) do
      build(:objective_task, organization: org, objective: objective, assigned_to: employee)
    end
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:objective) }
    it { is_expected.to belong_to(:assigned_to).class_name('Employee') }
  end

  describe '#complete!' do
    it 'transitions todo → done' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.complete!(employee)
        expect(task.reload.status).to eq('done')
        expect(task.completed_by).to eq(employee)
        expect(task.completed_at).to be_present
      end
    end

    it 'raises if already validated' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'validated')
        expect { task.complete!(employee) }.to raise_error(ObjectiveTask::InvalidTransitionError, /validated/)
      end
    end
  end

  describe '#validate_task!' do
    it 'transitions done → validated' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'done')
        task.validate_task!(manager)
        expect(task.reload.status).to eq('validated')
        expect(task.validated_by).to eq(manager)
        expect(task.validated_at).to be_present
      end
    end

    it 'raises if not done' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        expect { task.validate_task!(manager) }.to raise_error(ObjectiveTask::InvalidTransitionError, /not done/)
      end
    end
  end

  describe 'cross-tenant validation' do
    let(:other_org)     { create(:organization) }
    let(:other_manager) { create(:employee, :manager, organization: other_org) }
    let(:other_emp)     { create(:employee, organization: other_org) }
    let(:other_objective) do
      ActsAsTenant.with_tenant(other_org) do
        create(:objective, organization: other_org, manager: other_manager,
               owner: other_emp, created_by: other_manager)
      end
    end

    it 'is invalid when objective belongs to different org' do
      ActsAsTenant.with_tenant(org) do
        bad_task = build(:objective_task, organization: org,
                         objective: other_objective, assigned_to: employee)
        expect(bad_task).not_to be_valid
      end
    end

    it 'is invalid when assigned_to belongs to different org' do
      # Force other_emp to be created before entering the tenant scope,
      # because acts_as_tenant silently overrides organization_id inside with_tenant.
      emp_from_other_org = other_emp
      ActsAsTenant.with_tenant(org) do
        bad_task = build(:objective_task, organization: org,
                         objective: objective, assigned_to: emp_from_other_org)
        expect(bad_task).not_to be_valid
      end
    end
  end

  describe 'Objective#progress_percentage' do
    let(:objective_with_tasks) do
      ActsAsTenant.with_tenant(org) do
        obj = create(:objective, organization: org, manager: manager, owner: employee, created_by: manager)
        obj
      end
    end

    it 'returns nil when no tasks' do
      ActsAsTenant.with_tenant(org) do
        expect(objective_with_tasks.progress_percentage).to be_nil
      end
    end

    it 'returns 0 when no tasks validated' do
      ActsAsTenant.with_tenant(org) do
        create(:objective_task, organization: org, objective: objective_with_tasks, assigned_to: employee)
        create(:objective_task, :done, organization: org, objective: objective_with_tasks, assigned_to: employee)
        objective_with_tasks.objective_tasks.reload
        expect(objective_with_tasks.progress_percentage).to eq(0)
      end
    end

    it 'returns 50 when half tasks validated' do
      ActsAsTenant.with_tenant(org) do
        create(:objective_task, organization: org, objective: objective_with_tasks, assigned_to: employee)
        create(:objective_task, :validated, organization: org, objective: objective_with_tasks, assigned_to: employee)
        objective_with_tasks.objective_tasks.reload
        expect(objective_with_tasks.progress_percentage).to eq(50)
      end
    end

    it 'returns 100 when all tasks validated' do
      ActsAsTenant.with_tenant(org) do
        create(:objective_task, :validated, organization: org, objective: objective_with_tasks, assigned_to: employee)
        objective_with_tasks.objective_tasks.reload
        expect(objective_with_tasks.progress_percentage).to eq(100)
      end
    end

    it 'tasks? returns false when no tasks' do
      ActsAsTenant.with_tenant(org) do
        expect(objective_with_tasks.tasks?).to be false
      end
    end

    it 'tasks? returns true when tasks exist' do
      ActsAsTenant.with_tenant(org) do
        create(:objective_task, organization: org, objective: objective_with_tasks, assigned_to: employee)
        expect(objective_with_tasks.tasks?).to be true
      end
    end
  end
end
