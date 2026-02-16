require 'rails_helper'

RSpec.describe ActionItemPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr) { create(:employee, organization: organization, role: 'hr') }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
  let(:other_employee) { create(:employee, organization: organization, manager: other_manager) }

  subject { described_class }

  describe 'Scope' do
    let(:one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }
    let(:other_one_on_one) { create(:one_on_one, organization: organization, manager: other_manager, employee: other_employee) }
    let!(:action_item) { create(:action_item, one_on_one: one_on_one, responsible: employee) }
    let!(:other_action_item) { create(:action_item, one_on_one: other_one_on_one, responsible: other_employee) }

    context 'as HR' do
      it 'returns all action items in organization' do
        resolved = ActionItemPolicy::Scope.new(hr, ActionItem).resolve
        expect(resolved).to include(action_item, other_action_item)
      end
    end

    context 'as manager' do
      it 'returns action items from their one-on-ones or where they are responsible' do
        resolved = ActionItemPolicy::Scope.new(manager, ActionItem).resolve
        expect(resolved).to include(action_item)
        expect(resolved).not_to include(other_action_item)
      end
    end

    context 'as employee' do
      it 'returns only action items where user is responsible' do
        resolved = ActionItemPolicy::Scope.new(employee, ActionItem).resolve
        expect(resolved).to include(action_item)
        expect(resolved).not_to include(other_action_item)
      end
    end
  end

  permissions :create? do
    let(:one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }
    let(:action_item) { build(:action_item, one_on_one: one_on_one, responsible: employee) }

    it 'allows HR to create action items' do
      expect(subject).to permit(hr, action_item)
    end

    it 'allows manager to create action items for their one-on-ones' do
      expect(subject).to permit(manager, action_item)
    end

    it 'denies other managers from creating action items' do
      expect(subject).not_to permit(other_manager, action_item)
    end

    it 'denies employees from creating action items' do
      expect(subject).not_to permit(employee, action_item)
    end
  end

  permissions :update?, :complete? do
    let(:one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }
    let(:action_item) { create(:action_item, one_on_one: one_on_one, responsible: employee) }

    it 'allows HR to update action items' do
      expect(subject).to permit(hr, action_item)
    end

    it 'allows responsible employee to update their action items' do
      expect(subject).to permit(employee, action_item)
    end

    it 'allows manager to update action items from their one-on-ones' do
      expect(subject).to permit(manager, action_item)
    end

    it 'denies other employees from updating action items' do
      expect(subject).not_to permit(other_employee, action_item)
    end
  end
end
