require 'rails_helper'

RSpec.describe ActionItem, type: :model do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }

  describe 'associations' do
    it { should belong_to(:one_on_one) }
    it { should belong_to(:responsible) }
    it { should belong_to(:objective).optional }
  end

  describe 'validations' do
    subject { build(:action_item, one_on_one: one_on_one, responsible: employee) }

    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description).is_at_most(1000) }
    it { should validate_presence_of(:deadline) }
    it { should validate_presence_of(:status) }
  end

  describe 'enums' do
    it 'defines status enum values' do
      expect(ActionItem.statuses.keys).to contain_exactly('pending', 'in_progress', 'completed', 'cancelled')
    end

    it 'defines responsible_type enum values' do
      expect(ActionItem.responsible_types.keys).to contain_exactly('manager', 'employee')
    end
  end

  describe 'scopes' do
    let!(:pending_item) { create(:action_item, one_on_one: one_on_one, responsible: employee, status: :pending) }
    let!(:in_progress_item) { create(:action_item, :in_progress, one_on_one: one_on_one, responsible: employee) }
    let!(:completed_item) { create(:action_item, :completed, one_on_one: one_on_one, responsible: employee) }
    let!(:overdue_item) { create(:action_item, :overdue, one_on_one: one_on_one, responsible: employee) }

    describe '.active' do
      it 'returns pending and in_progress items' do
        expect(ActionItem.active).to include(pending_item, in_progress_item, overdue_item)
        expect(ActionItem.active).not_to include(completed_item)
      end
    end

    describe '.overdue' do
      it 'returns active items with deadline in the past' do
        expect(ActionItem.overdue).to include(overdue_item)
        expect(ActionItem.overdue).not_to include(pending_item, in_progress_item, completed_item)
      end
    end

    describe '.for_responsible' do
      it 'returns items for specific employee' do
        other_employee = create(:employee, organization: organization)
        other_item = create(:action_item, one_on_one: one_on_one, responsible: other_employee)

        expect(ActionItem.for_responsible(employee)).to include(pending_item, in_progress_item)
        expect(ActionItem.for_responsible(employee)).not_to include(other_item)
      end
    end
  end

  describe 'instance methods' do
    describe '#overdue?' do
      it 'returns true if active and deadline is past' do
        action_item = create(:action_item, :overdue, one_on_one: one_on_one, responsible: employee)
        expect(action_item.overdue?).to be true
      end

      it 'returns false if completed' do
        action_item = create(:action_item, :completed, one_on_one: one_on_one, responsible: employee)
        expect(action_item.overdue?).to be false
      end

      it 'returns false if deadline is in future' do
        action_item = create(:action_item, one_on_one: one_on_one, responsible: employee, deadline: 1.week.from_now)
        expect(action_item.overdue?).to be false
      end
    end

    describe '#active?' do
      it 'returns true for pending status' do
        action_item = create(:action_item, one_on_one: one_on_one, responsible: employee, status: :pending)
        expect(action_item.active?).to be true
      end

      it 'returns true for in_progress status' do
        action_item = create(:action_item, :in_progress, one_on_one: one_on_one, responsible: employee)
        expect(action_item.active?).to be true
      end

      it 'returns false for completed status' do
        action_item = create(:action_item, :completed, one_on_one: one_on_one, responsible: employee)
        expect(action_item.active?).to be false
      end
    end

    describe '#complete!' do
      it 'marks action item as completed and sets completed_at' do
        action_item = create(:action_item, one_on_one: one_on_one, responsible: employee)
        expect {
          action_item.complete!
        }.to change { action_item.reload.status }.to('completed')
          .and change { action_item.completed_at }.from(nil)
      end

      it 'is idempotent — does not update completed_at when already completed' do
        action_item = create(:action_item, one_on_one: one_on_one, responsible: employee)
        action_item.complete!
        original_completed_at = action_item.reload.completed_at

        travel 1.hour do
          action_item.complete!
        end

        expect(action_item.reload.completed_at).to eq(original_completed_at)
      end
    end
  end

  describe 'optional objective link' do
    it 'can be linked to an objective' do
      objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)
      action_item = create(:action_item, one_on_one: one_on_one, responsible: employee, objective: objective)
      expect(action_item.objective).to eq(objective)
    end

    it 'can exist without an objective' do
      action_item = create(:action_item, one_on_one: one_on_one, responsible: employee)
      expect(action_item.objective).to be_nil
    end
  end
end
