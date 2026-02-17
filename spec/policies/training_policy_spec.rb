require 'rails_helper'

RSpec.describe TrainingPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr) { create(:employee, organization: organization, role: 'hr') }
  let(:admin) { create(:employee, organization: organization, role: 'admin') }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:training) { create(:training, organization: organization) }
  let(:archived_training) { create(:training, :archived, organization: organization) }

  subject { described_class }

  describe 'Scope' do
    it 'returns all trainings for hr' do
      ActsAsTenant.with_tenant(organization) do
        training
        archived_training
        scope = described_class::Scope.new(hr, Training.all).resolve
        expect(scope).to include(training, archived_training)
      end
    end

    it 'returns only active trainings for managers' do
      ActsAsTenant.with_tenant(organization) do
        training
        archived_training
        scope = described_class::Scope.new(manager, Training.all).resolve
        expect(scope).to include(training)
        expect(scope).not_to include(archived_training)
      end
    end

    it 'returns only active trainings for employees' do
      ActsAsTenant.with_tenant(organization) do
        training
        archived_training
        scope = described_class::Scope.new(employee, Training.all).resolve
        expect(scope).to include(training)
        expect(scope).not_to include(archived_training)
      end
    end
  end

  permissions :create? do
    it 'permits manager' do
      expect(subject).to permit(manager, Training.new)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, Training.new)
    end

    it 'denies employee' do
      expect(subject).not_to permit(employee, Training.new)
    end
  end

  permissions :update? do
    it 'permits hr' do
      expect(subject).to permit(hr, training)
    end

    it 'permits admin' do
      expect(subject).to permit(admin, training)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, training)
    end

    it 'denies employee' do
      expect(subject).not_to permit(employee, training)
    end
  end

  permissions :archive? do
    it 'permits hr' do
      expect(subject).to permit(hr, training)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, training)
    end

    it 'denies employee' do
      expect(subject).not_to permit(employee, training)
    end
  end

  permissions :destroy? do
    it 'permits hr' do
      expect(subject).to permit(hr, training)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, training)
    end
  end
end
