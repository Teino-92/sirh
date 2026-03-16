# frozen_string_literal: true

require 'rails_helper'

# Tests delegation support in ApprovalChainService#can_approve?
RSpec.describe ApprovalChainService, 'with delegation' do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }
  let(:leave_request) { create(:leave_request, employee: employee) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  subject(:service) { described_class.new(leave_request) }

  def create_step(role:)
    ApprovalStep.create!(
      organization: org, resource_type: 'LeaveRequest', resource_id: leave_request.id,
      step_order: 1, required_role: role, status: 'pending'
    )
  end

  def create_delegation(delegator:, delegatee:, role:, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
    EmployeeDelegation.create!(
      organization: org, delegator: delegator, delegatee: delegatee,
      role: role, starts_at: starts_at, ends_at: ends_at
    )
  end

  describe '#advance! with active delegation' do
    let!(:step) { create_step(role: 'manager') }

    it 'allows an employee with active delegation to approve' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager')
      expect { service.advance!(approver: hr) }.not_to raise_error
      expect(step.reload.status).to eq('approved')
    end

    it 'rejects an employee with expired delegation' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager',
                        starts_at: 2.hours.ago, ends_at: 1.hour.ago)
      expect { service.advance!(approver: hr) }.to raise_error(RuntimeError, /cannot approve/)
    end

    it 'rejects an employee with future delegation' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager',
                        starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
      expect { service.advance!(approver: hr) }.to raise_error(RuntimeError, /cannot approve/)
    end

    it 'delegator retains their own approval rights' do
      create_delegation(delegator: manager, delegatee: hr, role: 'manager')
      expect { service.advance!(approver: manager) }.not_to raise_error
    end
  end
end
