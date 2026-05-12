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
        expect { task.complete!(employee) }.to raise_error(RuntimeError, /validated/)
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
        expect { task.validate_task!(manager) }.to raise_error(RuntimeError, /not done/)
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
  end
end
