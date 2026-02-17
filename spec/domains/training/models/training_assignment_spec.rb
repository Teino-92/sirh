require 'rails_helper'

RSpec.describe TrainingAssignment, type: :model do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:training) { create(:training, organization: organization) }

  describe 'associations' do
    it { should belong_to(:training) }
    it { should belong_to(:employee) }
    it { should belong_to(:assigned_by) }
    it { should belong_to(:objective).optional }
  end

  describe 'validations' do
    subject do
      build(:training_assignment,
        training: training,
        employee: employee,
        assigned_by: manager
      )
    end

    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:assigned_at) }

    it 'defines status enum values' do
      expect(TrainingAssignment.statuses.keys).to contain_exactly(
        'assigned', 'in_progress', 'completed', 'cancelled'
      )
    end

    context 'same organization validation' do
      it 'is invalid when assigned_by is from a different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, organization: other_org, role: 'manager')

        assignment = build(:training_assignment,
          training: training,
          employee: employee,
          assigned_by: other_manager
        )

        expect(assignment).not_to be_valid
        expect(assignment.errors[:assigned_by]).to include('must belong to the same organization as the training')
      end

      it 'is invalid when employee is from a different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)

        assignment = build(:training_assignment,
          training: training,
          employee: other_employee,
          assigned_by: manager
        )

        expect(assignment).not_to be_valid
        expect(assignment.errors[:employee]).to include('must belong to the same organization as the training')
      end
    end
  end

  describe 'scopes' do
    let(:training2) { create(:training, organization: organization) }
    let(:training3) { create(:training, organization: organization) }

    before do
      # Each assignment uses a distinct training to avoid unique partial index violation
      # (unique active assignment per employee/training)
      create(:training_assignment, training: training, employee: employee, assigned_by: manager,
             status: :assigned, assigned_at: Date.current)
      create(:training_assignment, training: training2, employee: employee, assigned_by: manager,
             status: :in_progress, assigned_at: Date.current)
      create(:training_assignment, :completed, training: training3, employee: manager, assigned_by: manager,
             assigned_at: Date.current)
    end

    describe '.active' do
      it 'returns assigned and in_progress assignments' do
        expect(TrainingAssignment.active.count).to eq(2)
      end
    end

    describe '.for_employee' do
      it 'returns assignments for a specific employee' do
        expect(TrainingAssignment.for_employee(employee).count).to eq(2)
      end
    end

    describe '.for_manager' do
      it 'returns assignments created by a specific manager' do
        expect(TrainingAssignment.for_manager(manager).count).to eq(3)
      end
    end
  end

  describe 'instance methods' do
    let(:assignment) do
      create(:training_assignment,
        training: training,
        employee: employee,
        assigned_by: manager,
        status: :assigned,
        assigned_at: Date.current
      )
    end

    describe '#complete!' do
      it 'marks assignment as completed and sets completed_at' do
        expect { assignment.complete! }
          .to change { assignment.reload.status }.to('completed')
          .and change { assignment.completed_at }.from(nil)
      end

      it 'stores completion notes when provided' do
        assignment.complete!(notes: 'Completed successfully')
        expect(assignment.reload.completion_notes).to eq('Completed successfully')
      end

      it 'is idempotent — does not update completed_at when already completed' do
        assignment.complete!
        original_completed_at = assignment.reload.completed_at

        travel 1.hour do
          assignment.complete!
        end

        expect(assignment.reload.completed_at).to eq(original_completed_at)
      end
    end

    describe '#overdue?' do
      it 'returns false when no deadline' do
        expect(assignment.overdue?).to be false
      end

      it 'returns false when deadline is in the future' do
        assignment.update!(deadline: 1.week.from_now.to_date)
        expect(assignment.overdue?).to be false
      end

      it 'returns true when deadline is in the past and status is active' do
        assignment.update!(deadline: 1.week.ago.to_date)
        expect(assignment.overdue?).to be true
      end

      it 'returns false when completed even if past deadline' do
        assignment.update_columns(status: 'completed', deadline: 1.week.ago.to_date)
        expect(assignment.overdue?).to be false
      end
    end

    describe '#active?' do
      it 'returns true when assigned' do
        expect(assignment.active?).to be true
      end

      it 'returns true when in_progress' do
        assignment.update!(status: :in_progress)
        expect(assignment.active?).to be true
      end

      it 'returns false when completed' do
        assignment.update_columns(status: 'completed')
        expect(assignment.active?).to be false
      end
    end
  end
end
