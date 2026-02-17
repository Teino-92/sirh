require 'rails_helper'

RSpec.describe TrainingAssignmentPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr) { create(:employee, organization: organization, role: 'hr') }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:other_employee) { create(:employee, organization: organization, manager: other_manager) }
  let(:training) { create(:training, organization: organization) }
  let(:assignment) do
    create(:training_assignment,
      training: training,
      employee: employee,
      assigned_by: manager,
      assigned_at: Date.current
    )
  end

  subject { described_class }

  describe 'Scope' do
    let(:training2) { create(:training, organization: organization) }
    let!(:my_assignment) do
      create(:training_assignment, training: training, employee: employee, assigned_by: manager, assigned_at: Date.current)
    end
    let!(:other_assignment) do
      create(:training_assignment, training: training2, employee: other_employee, assigned_by: other_manager, assigned_at: Date.current)
    end

    it 'returns all assignments for hr' do
      scope = described_class::Scope.new(hr, TrainingAssignment.all).resolve
      expect(scope).to include(my_assignment, other_assignment)
    end

    it 'returns manager assignments for manager' do
      scope = described_class::Scope.new(manager, TrainingAssignment.all).resolve
      expect(scope).to include(my_assignment)
      expect(scope).not_to include(other_assignment)
    end

    it 'returns only own assignments for employee' do
      scope = described_class::Scope.new(employee, TrainingAssignment.all).resolve
      expect(scope).to include(my_assignment)
      expect(scope).not_to include(other_assignment)
    end
  end

  permissions :create? do
    it 'permits manager' do
      expect(subject).to permit(manager, TrainingAssignment.new)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, TrainingAssignment.new)
    end

    it 'denies employee' do
      expect(subject).not_to permit(employee, TrainingAssignment.new)
    end
  end

  permissions :complete? do
    it 'permits the assigned employee' do
      expect(subject).to permit(employee, assignment)
    end

    it 'permits the assigning manager' do
      expect(subject).to permit(manager, assignment)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, assignment)
    end

    it 'denies other employees' do
      expect(subject).not_to permit(other_employee, assignment)
    end

    it 'denies other managers' do
      expect(subject).not_to permit(other_manager, assignment)
    end
  end

  permissions :update? do
    it 'permits hr' do
      expect(subject).to permit(hr, assignment)
    end

    it 'permits assigning manager' do
      expect(subject).to permit(manager, assignment)
    end

    it 'denies other manager' do
      expect(subject).not_to permit(other_manager, assignment)
    end

    it 'denies employee' do
      expect(subject).not_to permit(employee, assignment)
    end
  end

  permissions :destroy? do
    it 'permits hr' do
      expect(subject).to permit(hr, assignment)
    end

    it 'permits assigning manager' do
      expect(subject).to permit(manager, assignment)
    end

    it 'denies other manager' do
      expect(subject).not_to permit(other_manager, assignment)
    end
  end
end
