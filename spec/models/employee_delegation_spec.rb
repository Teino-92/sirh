# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeDelegation do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  def build_delegation(overrides = {})
    EmployeeDelegation.new({
      organization: org,
      delegator:    manager,
      delegatee:    hr,
      role:         'manager',
      starts_at:    1.hour.ago,
      ends_at:      1.hour.from_now
    }.merge(overrides))
  end

  describe 'validations' do
    it 'is valid with correct attributes' do
      expect(build_delegation).to be_valid
    end

    it 'rejects self-delegation' do
      d = build_delegation(delegatee: manager)
      expect(d).not_to be_valid
      expect(d.errors[:delegatee]).to be_present
    end

    it 'rejects ends_at before starts_at' do
      d = build_delegation(starts_at: 1.hour.from_now, ends_at: 1.hour.ago)
      expect(d).not_to be_valid
      expect(d.errors[:ends_at]).to be_present
    end

    it 'rejects delegating a role the delegator does not have' do
      d = build_delegation(delegator: employee, role: 'hr')
      expect(d).not_to be_valid
      expect(d.errors[:role]).to be_present
    end

    it 'allows admin to delegate any role' do
      admin = create(:employee, organization: org, role: 'admin')
      d = build_delegation(delegator: admin, role: 'hr')
      expect(d).to be_valid
    end
  end

  describe '.active_now' do
    it 'returns delegations currently active' do
      active = EmployeeDelegation.create!(
        organization: org, delegator: manager, delegatee: hr, role: 'manager',
        starts_at: 1.hour.ago, ends_at: 1.hour.from_now
      )
      expect(EmployeeDelegation.active_now).to include(active)
    end

    it 'excludes expired delegations' do
      EmployeeDelegation.create!(
        organization: org, delegator: manager, delegatee: hr, role: 'manager',
        starts_at: 2.hours.ago, ends_at: 1.hour.ago
      )
      expect(EmployeeDelegation.active_now).to be_empty
    end

    it 'excludes future delegations' do
      EmployeeDelegation.create!(
        organization: org, delegator: manager, delegatee: hr, role: 'manager',
        starts_at: 1.hour.from_now, ends_at: 2.hours.from_now
      )
      expect(EmployeeDelegation.active_now).to be_empty
    end
  end
end
