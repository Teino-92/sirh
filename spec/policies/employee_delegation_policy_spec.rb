# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeDelegationPolicy, type: :policy do
  let(:sirh_org)  { create(:organization, plan: 'sirh') }
  let(:os_org)    { create(:organization, plan: 'manager_os') }

  let(:admin)    { create(:employee, organization: sirh_org, role: 'admin') }
  let(:hr)       { create(:employee, organization: sirh_org, role: 'hr') }
  let(:manager)  { create(:employee, organization: sirh_org, role: 'manager') }
  let(:employee) { create(:employee, organization: sirh_org, role: 'employee') }

  let(:os_manager) { create(:employee, organization: os_org, role: 'manager') }

  before { ActsAsTenant.current_tenant = sirh_org }
  after  { ActsAsTenant.current_tenant = nil }

  def delegation_for(delegator, delegatee = employee)
    ActsAsTenant.with_tenant(delegator.organization) do
      build(:employee_delegation,
            organization: delegator.organization,
            delegator:    delegator,
            delegatee:    delegatee,
            role:         'manager')
    end
  end

  subject { described_class }

  permissions :index? do
    it 'permits admin on SIRH plan' do
      expect(subject).to permit(admin, EmployeeDelegation)
    end

    it 'permits manager on SIRH plan' do
      expect(subject).to permit(manager, EmployeeDelegation)
    end

    it 'permits hr on SIRH plan' do
      expect(subject).to permit(hr, EmployeeDelegation)
    end

    it 'permits plain employee on SIRH plan' do
      expect(subject).to permit(employee, EmployeeDelegation)
    end

    it 'denies on manager_os plan' do
      ActsAsTenant.with_tenant(os_org) do
        expect(subject).not_to permit(os_manager, EmployeeDelegation)
      end
    end
  end

  permissions :new?, :create? do
    it 'permits manager on SIRH plan' do
      expect(subject).to permit(manager, delegation_for(manager))
    end

    it 'permits hr on SIRH plan' do
      expect(subject).to permit(hr, delegation_for(hr))
    end

    it 'permits admin on SIRH plan' do
      expect(subject).to permit(admin, delegation_for(admin))
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, delegation_for(manager))
    end

    it 'denies on manager_os plan' do
      ActsAsTenant.with_tenant(os_org) do
        expect(subject).not_to permit(os_manager, delegation_for(os_manager))
      end
    end
  end

  permissions :destroy? do
    it 'permits the delegator to revoke their own delegation' do
      record = delegation_for(manager, hr)
      expect(subject).to permit(manager, record)
    end

    it 'permits admin to revoke any delegation' do
      record = delegation_for(manager, hr)
      expect(subject).to permit(admin, record)
    end

    it 'denies delegatee from revoking the delegation' do
      record = delegation_for(manager, hr)
      expect(subject).not_to permit(hr, record)
    end

    it 'denies plain employee' do
      record = delegation_for(manager, hr)
      expect(subject).not_to permit(employee, record)
    end
  end

  describe 'Scope' do
    before { ActsAsTenant.current_tenant = sirh_org }

    let(:other_employee) { create(:employee, organization: sirh_org, role: 'employee') }
    let!(:delegation_as_delegator) do
      ActsAsTenant.with_tenant(sirh_org) do
        create(:employee_delegation, organization: sirh_org, delegator: manager, delegatee: hr, role: 'manager')
      end
    end
    let!(:delegation_as_delegatee) do
      ActsAsTenant.with_tenant(sirh_org) do
        create(:employee_delegation, organization: sirh_org, delegator: hr, delegatee: manager, role: 'hr')
      end
    end
    let!(:unrelated_delegation) do
      ActsAsTenant.with_tenant(sirh_org) do
        create(:employee_delegation, organization: sirh_org, delegator: hr, delegatee: employee, role: 'hr')
      end
    end

    it 'returns delegations where user is delegator or delegatee' do
      scope = described_class::Scope.new(manager, EmployeeDelegation.all).resolve
      expect(scope).to include(delegation_as_delegator, delegation_as_delegatee)
    end

    it 'excludes delegations where user is neither party' do
      scope = described_class::Scope.new(other_employee, EmployeeDelegation.all).resolve
      expect(scope).not_to include(delegation_as_delegator, delegation_as_delegatee)
    end
  end
end
