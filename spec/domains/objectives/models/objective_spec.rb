require 'rails_helper'

RSpec.describe Objective, type: :model do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:owner) }
    it { should belong_to(:manager) }
    it { should belong_to(:created_by) }
    it { should have_many(:one_on_one_objectives).dependent(:nullify) }
    it { should have_many(:one_on_ones).through(:one_on_one_objectives) }
  end

  describe 'validations' do
    subject { build(:objective, organization: organization, manager: manager, created_by: manager, owner: employee) }

    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(5000) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:deadline) }

    context 'deadline in future validation' do
      it 'is invalid if deadline is in the past on create' do
        objective = build(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, deadline: 1.day.ago)
        expect(objective).not_to be_valid
        expect(objective.errors[:deadline]).to include('must be in the future')
      end

      it 'is valid if deadline is in the future' do
        objective = build(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, deadline: 1.week.from_now)
        expect(objective).to be_valid
      end
    end

    context 'same organization validation' do
      it 'is invalid if manager is from different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, organization: other_org, role: 'manager')
        objective = build(:objective, organization: organization, manager: other_manager, created_by: manager, owner: employee)
        expect(objective).not_to be_valid
        expect(objective.errors[:manager]).to include('must belong to the same organization')
      end

      it 'is invalid if owner is from different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)
        objective = build(:objective, organization: organization, manager: manager, created_by: manager, owner: other_employee)
        expect(objective).not_to be_valid
        expect(objective.errors[:owner]).to include('must belong to the same organization')
      end
    end
  end

  describe 'enums' do
    it 'defines status enum values' do
      expect(Objective.statuses.keys).to contain_exactly('draft', 'in_progress', 'completed', 'blocked', 'cancelled')
    end

    it 'defines priority enum values' do
      expect(Objective.priorities.keys).to contain_exactly('low', 'medium', 'high', 'critical')
    end
  end

  describe 'scopes' do
    let!(:draft_objective) { create(:objective, :draft, organization: organization, manager: manager, created_by: manager, owner: employee) }
    let!(:in_progress_objective) { create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :in_progress) }
    let!(:completed_objective) { create(:objective, :completed, organization: organization, manager: manager, created_by: manager, owner: employee) }
    let!(:overdue_objective) do
      obj = build(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :in_progress, deadline: 1.week.ago)
      obj.save(validate: false)
      obj
    end

    describe '.active' do
      it 'returns objectives with draft, in_progress, or blocked status' do
        expect(Objective.active).to include(draft_objective, in_progress_objective, overdue_objective)
        expect(Objective.active).not_to include(completed_objective)
      end
    end

    describe '.overdue' do
      it 'returns active objectives with deadline in the past' do
        expect(Objective.overdue).to include(overdue_objective)
        expect(Objective.overdue).not_to include(draft_objective, in_progress_objective, completed_objective)
      end
    end

    describe '.upcoming' do
      it 'returns active objectives with deadline in next 30 days' do
        upcoming = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, deadline: 2.weeks.from_now)
        expect(Objective.upcoming).to include(upcoming)
      end
    end

    describe '.for_manager' do
      it 'returns objectives for specific manager' do
        other_manager = create(:employee, organization: organization, role: 'manager')
        other_objective = create(:objective, organization: organization, manager: other_manager, created_by: other_manager, owner: employee)

        expect(Objective.for_manager(manager)).to include(draft_objective, in_progress_objective)
        expect(Objective.for_manager(manager)).not_to include(other_objective)
      end
    end

    describe '.for_owner' do
      it 'returns objectives for specific owner' do
        other_employee = create(:employee, organization: organization)
        other_objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: other_employee)

        expect(Objective.for_owner(employee)).to include(draft_objective, in_progress_objective)
        expect(Objective.for_owner(employee)).not_to include(other_objective)
      end
    end
  end

  describe 'instance methods' do
    describe '#overdue?' do
      it 'returns true if active and deadline is past' do
        objective = build(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :in_progress, deadline: 1.week.ago)
        objective.save(validate: false)
        expect(objective.overdue?).to be true
      end

      it 'returns false if completed' do
        objective = create(:objective, :completed, organization: organization, manager: manager, created_by: manager, owner: employee)
        expect(objective.overdue?).to be false
      end

      it 'returns false if deadline is in future' do
        objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, deadline: 1.week.from_now)
        expect(objective.overdue?).to be false
      end
    end

    describe '#active?' do
      it 'returns true for draft status' do
        objective = create(:objective, :draft, organization: organization, manager: manager, created_by: manager, owner: employee)
        expect(objective.active?).to be true
      end

      it 'returns true for in_progress status' do
        objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :in_progress)
        expect(objective.active?).to be true
      end

      it 'returns false for completed status' do
        objective = create(:objective, :completed, organization: organization, manager: manager, created_by: manager, owner: employee)
        expect(objective.active?).to be false
      end
    end

    describe '#complete!' do
      it 'marks objective as completed and sets completed_at' do
        objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)
        expect {
          objective.complete!
        }.to change { objective.reload.status }.to('completed')
          .and change { objective.completed_at }.from(nil)
      end

      it 'is idempotent — does not update completed_at when already completed' do
        objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)
        objective.complete!
        original_completed_at = objective.reload.completed_at

        travel 1.hour do
          objective.complete!
        end

        expect(objective.reload.completed_at).to eq(original_completed_at)
      end
    end
  end

  describe 'multi-tenancy' do
    it 'scopes objectives to organization' do
      org1 = create(:organization)
      org2 = create(:organization)
      manager1 = create(:employee, organization: org1, role: 'manager')
      manager2 = create(:employee, organization: org2, role: 'manager')
      employee1 = create(:employee, organization: org1)
      employee2 = create(:employee, organization: org2)

      ActsAsTenant.with_tenant(org1) do
        create(:objective, organization: org1, manager: manager1, created_by: manager1, owner: employee1)
      end

      ActsAsTenant.with_tenant(org2) do
        create(:objective, organization: org2, manager: manager2, created_by: manager2, owner: employee2)
      end

      ActsAsTenant.with_tenant(org1) do
        expect(Objective.count).to eq(1)
      end

      ActsAsTenant.with_tenant(org2) do
        expect(Objective.count).to eq(1)
      end
    end
  end
end
