require 'rails_helper'

RSpec.describe ObjectivePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr) { create(:employee, organization: organization, role: 'hr') }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
  let(:other_employee) { create(:employee, organization: organization, manager: other_manager) }

  subject { described_class }

  describe 'Scope' do
    let!(:manager_objective) { create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee) }
    let!(:employee_owned_objective) { create(:objective, organization: organization, manager: other_manager, created_by: other_manager, owner: employee) }
    let!(:other_objective) { create(:objective, organization: organization, manager: other_manager, created_by: other_manager, owner: other_employee) }

    context 'as HR' do
      it 'returns all objectives in organization' do
        resolved = ObjectivePolicy::Scope.new(hr, Objective).resolve
        expect(resolved).to include(manager_objective, employee_owned_objective, other_objective)
      end
    end

    context 'as manager' do
      it 'returns objectives managed by or owned by the manager' do
        resolved = ObjectivePolicy::Scope.new(manager, Objective).resolve
        expect(resolved).to include(manager_objective)
        expect(resolved).not_to include(other_objective)
      end
    end

    context 'as employee' do
      it 'returns only objectives owned by the employee' do
        resolved = ObjectivePolicy::Scope.new(employee, Objective).resolve
        expect(resolved).to include(manager_objective, employee_owned_objective)
        expect(resolved).not_to include(other_objective)
      end
    end
  end

  permissions :create? do
    it 'allows HR to create objectives' do
      expect(subject).to permit(hr, Objective.new)
    end

    it 'allows managers to create objectives' do
      expect(subject).to permit(manager, Objective.new)
    end

    it 'denies employees from creating objectives' do
      expect(subject).not_to permit(employee, Objective.new)
    end
  end

  permissions :update?, :destroy?, :complete? do
    let(:objective) { create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee) }

    it 'allows HR to update/destroy objectives' do
      expect(subject).to permit(hr, objective)
    end

    it 'allows manager to update/destroy their team objectives' do
      expect(subject).to permit(manager, objective)
    end

    it 'denies other managers from updating objectives' do
      expect(subject).not_to permit(other_manager, objective)
    end

    it 'denies employees from updating objectives' do
      expect(subject).not_to permit(employee, objective)
    end
  end
end
