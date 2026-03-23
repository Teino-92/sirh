# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DelegationResolver do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  def create_delegation(delegator:, delegatee:, role: 'manager', active: true,
                        starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
    create(:employee_delegation,
           organization: org,
           delegator:    delegator,
           delegatee:    delegatee,
           role:         role,
           active:       active,
           starts_at:    starts_at,
           ends_at:      ends_at)
  end

  describe '.can_act_as?' do
    context 'native role' do
      it 'returns true when employee already has the role' do
        expect(described_class.can_act_as?(manager, 'manager')).to be true
      end

      it 'returns true for admin regardless of role' do
        expect(described_class.can_act_as?(admin, 'manager')).to be true
        expect(described_class.can_act_as?(admin, 'hr')).to be true
      end

      it 'returns false when employee does not have the role and no delegation' do
        expect(described_class.can_act_as?(hr, 'manager')).to be false
      end
    end

    context 'via active delegation' do
      it 'returns true when an active delegation grants the role' do
        create_delegation(delegator: manager, delegatee: hr, role: 'manager')
        expect(described_class.can_act_as?(hr, 'manager')).to be true
      end

      it 'returns false when delegation exists but is inactive (active: false)' do
        create_delegation(delegator: manager, delegatee: hr, role: 'manager', active: false)
        expect(described_class.can_act_as?(hr, 'manager')).to be false
      end

      it 'returns false when delegation has not started yet' do
        create_delegation(delegator: manager, delegatee: hr, role: 'manager',
                          starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        expect(described_class.can_act_as?(hr, 'manager')).to be false
      end

      it 'returns false when delegation has expired' do
        create_delegation(delegator: manager, delegatee: hr, role: 'manager',
                          starts_at: 3.hours.ago, ends_at: 1.hour.ago)
        expect(described_class.can_act_as?(hr, 'manager')).to be false
      end

      it 'returns false when delegation is for a different role' do
        # hr delegates their 'hr' role to employee — employee should NOT get 'manager'
        create_delegation(delegator: hr, delegatee: employee, role: 'hr')
        expect(described_class.can_act_as?(employee, 'manager')).to be false
      end
    end

    context 'multi-tenant isolation' do
      let(:other_org)     { create(:organization) }
      let(:other_manager) { create(:employee, organization: other_org, role: 'manager') }

      it 'does not pick up delegations from another organization' do
        ActsAsTenant.with_tenant(other_org) do
          create(:employee_delegation,
                 organization: other_org,
                 delegator:    other_manager,
                 delegatee:    hr,
                 role:         'manager',
                 starts_at:    1.hour.ago,
                 ends_at:      1.hour.from_now)
        end

        ActsAsTenant.with_tenant(org) do
          expect(described_class.can_act_as?(hr, 'manager')).to be false
        end
      end
    end
  end

  describe '.delegated_manager_ids' do
    it 'returns empty array when no delegations exist' do
      expect(described_class.delegated_manager_ids(hr)).to eq []
    end

    it 'returns the delegator IDs for active manager delegations' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager')
      expect(described_class.delegated_manager_ids(hr)).to contain_exactly(manager.id)
    end

    it 'excludes inactive delegations' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager', active: false)
      expect(described_class.delegated_manager_ids(hr)).to be_empty
    end

    it 'excludes expired delegations' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager',
                        starts_at: 3.hours.ago, ends_at: 1.hour.ago)
      expect(described_class.delegated_manager_ids(hr)).to be_empty
    end

    it 'excludes delegations for other roles' do
      # hr delegates 'hr' role to employee — should not appear in manager delegations
      create_delegation(delegator: hr, delegatee: employee, role: 'hr')
      expect(described_class.delegated_manager_ids(employee, role: 'manager')).to be_empty
    end

    it 'supports custom role parameter' do
      create_delegation(delegator: hr, delegatee: employee, role: 'hr')
      expect(described_class.delegated_manager_ids(employee, role: 'hr')).to contain_exactly(hr.id)
    end

    it 'returns multiple delegator IDs when multiple managers delegate' do
      manager2 = create(:employee, organization: org, role: 'manager')
      create_delegation(delegator: manager,  delegatee: hr, role: 'manager')
      create_delegation(delegator: manager2, delegatee: hr, role: 'manager')
      expect(described_class.delegated_manager_ids(hr)).to contain_exactly(manager.id, manager2.id)
    end
  end
end
