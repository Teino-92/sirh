require 'rails_helper'

RSpec.describe OneOnOnePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr) { create(:employee, organization: organization, role: 'hr') }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
  let(:other_employee) { create(:employee, organization: organization, manager: other_manager) }

  subject { described_class }

  describe 'Scope' do
    let!(:manager_one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }
    let!(:other_one_on_one) { create(:one_on_one, organization: organization, manager: other_manager, employee: other_employee) }

    context 'as HR' do
      it 'returns all one-on-ones in organization' do
        resolved = OneOnOnePolicy::Scope.new(hr, OneOnOne).resolve
        expect(resolved).to include(manager_one_on_one, other_one_on_one)
      end
    end

    context 'as manager' do
      it 'returns one-on-ones where user is manager or employee' do
        resolved = OneOnOnePolicy::Scope.new(manager, OneOnOne).resolve
        expect(resolved).to include(manager_one_on_one)
        expect(resolved).not_to include(other_one_on_one)
      end
    end

    context 'as employee' do
      it 'returns only one-on-ones where user is the employee' do
        resolved = OneOnOnePolicy::Scope.new(employee, OneOnOne).resolve
        expect(resolved).to include(manager_one_on_one)
        expect(resolved).not_to include(other_one_on_one)
      end
    end
  end

  permissions :create? do
    it 'allows HR to create one-on-ones' do
      expect(subject).to permit(hr, OneOnOne.new)
    end

    it 'allows managers to create one-on-ones' do
      expect(subject).to permit(manager, OneOnOne.new)
    end

    it 'denies employees from creating one-on-ones' do
      expect(subject).not_to permit(employee, OneOnOne.new)
    end
  end

  permissions :update?, :destroy?, :complete? do
    let(:one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }

    it 'allows HR to update one-on-ones' do
      expect(subject).to permit(hr, one_on_one)
    end

    it 'allows manager to update their one-on-ones' do
      expect(subject).to permit(manager, one_on_one)
    end

    it 'denies other managers from updating one-on-ones' do
      expect(subject).not_to permit(other_manager, one_on_one)
    end

    it 'denies employees from updating one-on-ones' do
      expect(subject).not_to permit(employee, one_on_one)
    end
  end
end
