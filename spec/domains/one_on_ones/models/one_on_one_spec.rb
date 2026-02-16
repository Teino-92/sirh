require 'rails_helper'

RSpec.describe OneOnOne, type: :model do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:manager) }
    it { should belong_to(:employee) }
    it { should have_many(:action_items).dependent(:destroy) }
    it { should have_many(:one_on_one_objectives).dependent(:destroy) }
    it { should have_many(:objectives).through(:one_on_one_objectives) }
  end

  describe 'validations' do
    subject { build(:one_on_one, organization: organization, manager: manager, employee: employee) }

    it { should validate_presence_of(:scheduled_at) }
    it { should validate_presence_of(:status) }

    context 'manager different from employee validation' do
      it 'is invalid if manager and employee are the same' do
        one_on_one = build(:one_on_one, organization: organization, manager: manager, employee: manager)
        expect(one_on_one).not_to be_valid
        expect(one_on_one.errors[:employee]).to include('cannot be the same as manager')
      end

      it 'is valid if manager and employee are different' do
        one_on_one = build(:one_on_one, organization: organization, manager: manager, employee: employee)
        expect(one_on_one).to be_valid
      end
    end

    context 'manager role validation' do
      it 'is invalid if manager does not have manager role' do
        non_manager = create(:employee, organization: organization, role: 'employee')
        one_on_one = build(:one_on_one, organization: organization, manager: non_manager, employee: employee)
        expect(one_on_one).not_to be_valid
        expect(one_on_one.errors[:manager]).to include('must have manager role')
      end
    end

    context 'same organization validation' do
      it 'is invalid if manager is from different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, organization: other_org, role: 'manager')
        one_on_one = build(:one_on_one, organization: organization, manager: other_manager, employee: employee)
        expect(one_on_one).not_to be_valid
        expect(one_on_one.errors[:base]).to include('manager and employee must belong to the same organization')
      end

      it 'is invalid if employee is from different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)
        one_on_one = build(:one_on_one, organization: organization, manager: manager, employee: other_employee)
        expect(one_on_one).not_to be_valid
        expect(one_on_one.errors[:base]).to include('manager and employee must belong to the same organization')
      end
    end
  end

  describe 'enums' do
    it 'defines status enum values' do
      expect(OneOnOne.statuses.keys).to contain_exactly('scheduled', 'completed', 'cancelled', 'rescheduled')
    end
  end

  describe 'scopes' do
    let!(:upcoming_meeting) { create(:one_on_one, :upcoming, organization: organization, manager: manager, employee: employee) }
    let!(:past_meeting) { create(:one_on_one, :past, organization: organization, manager: manager, employee: employee) }
    let!(:far_future_meeting) { create(:one_on_one, organization: organization, manager: manager, employee: employee, scheduled_at: 1.year.from_now, status: :scheduled) }

    describe '.upcoming' do
      it 'returns scheduled meetings in the future' do
        expect(OneOnOne.upcoming).to include(upcoming_meeting, far_future_meeting)
        expect(OneOnOne.upcoming).not_to include(past_meeting)
      end
    end

    describe '.past' do
      it 'returns completed meetings' do
        expect(OneOnOne.past).to include(past_meeting)
        expect(OneOnOne.past).not_to include(upcoming_meeting)
      end
    end

    describe '.for_manager' do
      it 'returns meetings for specific manager' do
        other_manager = create(:employee, organization: organization, role: 'manager')
        other_employee = create(:employee, organization: organization)
        other_meeting = create(:one_on_one, organization: organization, manager: other_manager, employee: other_employee)

        expect(OneOnOne.for_manager(manager)).to include(upcoming_meeting, past_meeting)
        expect(OneOnOne.for_manager(manager)).not_to include(other_meeting)
      end
    end

    describe '.for_employee' do
      it 'returns meetings for specific employee' do
        other_employee = create(:employee, organization: organization)
        other_meeting = create(:one_on_one, organization: organization, manager: manager, employee: other_employee)

        expect(OneOnOne.for_employee(employee)).to include(upcoming_meeting, past_meeting)
        expect(OneOnOne.for_employee(employee)).not_to include(other_meeting)
      end
    end

    describe '.this_quarter' do
      it 'returns meetings from current quarter' do
        this_quarter_meeting = create(:one_on_one, organization: organization, manager: manager, employee: employee, scheduled_at: Date.current.beginning_of_quarter + 1.week)
        expect(OneOnOne.this_quarter).to include(this_quarter_meeting)
      end
    end
  end

  describe 'instance methods' do
    describe '#complete!' do
      it 'marks meeting as completed and sets completed_at' do
        one_on_one = create(:one_on_one, organization: organization, manager: manager, employee: employee)
        notes = 'Discussed quarterly goals'

        expect {
          one_on_one.complete!(notes: notes)
        }.to change { one_on_one.reload.status }.to('completed')
          .and change { one_on_one.completed_at }.from(nil)
          .and change { one_on_one.notes }.to(notes)
      end

      it 'touches pending action items' do
        one_on_one = create(:one_on_one, organization: organization, manager: manager, employee: employee)
        action_item = create(:action_item, one_on_one: one_on_one, responsible: employee, status: :pending)

        expect {
          one_on_one.complete!(notes: 'Notes')
        }.to change { action_item.reload.updated_at }
      end
    end

    describe '#overdue?' do
      it 'returns true if scheduled and scheduled_at is in the past' do
        one_on_one = create(:one_on_one, organization: organization, manager: manager, employee: employee, scheduled_at: 1.hour.ago, status: :scheduled)
        expect(one_on_one.overdue?).to be true
      end

      it 'returns false if completed' do
        one_on_one = create(:one_on_one, :completed, organization: organization, manager: manager, employee: employee)
        expect(one_on_one.overdue?).to be false
      end

      it 'returns false if scheduled_at is in future' do
        one_on_one = create(:one_on_one, organization: organization, manager: manager, employee: employee, scheduled_at: 1.week.from_now)
        expect(one_on_one.overdue?).to be false
      end
    end
  end

  describe 'multi-tenancy' do
    it 'scopes one_on_ones to organization' do
      org1 = create(:organization)
      org2 = create(:organization)
      manager1 = create(:employee, organization: org1, role: 'manager')
      manager2 = create(:employee, organization: org2, role: 'manager')
      employee1 = create(:employee, organization: org1)
      employee2 = create(:employee, organization: org2)

      ActsAsTenant.with_tenant(org1) do
        create(:one_on_one, organization: org1, manager: manager1, employee: employee1)
      end

      ActsAsTenant.with_tenant(org2) do
        create(:one_on_one, organization: org2, manager: manager2, employee: employee2)
      end

      ActsAsTenant.with_tenant(org1) do
        expect(OneOnOne.count).to eq(1)
      end

      ActsAsTenant.with_tenant(org2) do
        expect(OneOnOne.count).to eq(1)
      end
    end
  end
end
