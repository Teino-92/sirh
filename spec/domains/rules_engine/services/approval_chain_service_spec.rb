# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApprovalChainService do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }
  let(:leave_request) { create(:leave_request, employee: employee) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  subject(:service) { described_class.new(leave_request) }

  def create_step(order:, role:, status: 'pending')
    ApprovalStep.create!(
      organization:  org,
      resource_type: 'LeaveRequest',
      resource_id:   leave_request.id,
      step_order:    order,
      required_role: role,
      status:        status
    )
  end

  describe '#complete?' do
    it 'returns false when no steps exist' do
      expect(service.complete?).to be false
    end

    it 'returns false when steps are pending' do
      create_step(order: 1, role: 'manager')
      expect(service.complete?).to be false
    end

    it 'returns true when all steps approved' do
      create_step(order: 1, role: 'manager', status: 'approved')
      create_step(order: 2, role: 'hr',      status: 'approved')
      expect(service.complete?).to be true
    end
  end

  describe '#blocked?' do
    it 'returns false when no rejected steps' do
      create_step(order: 1, role: 'manager')
      expect(service.blocked?).to be false
    end

    it 'returns true when a step is rejected' do
      create_step(order: 1, role: 'manager', status: 'rejected')
      expect(service.blocked?).to be true
    end
  end

  describe '#advance!' do
    context 'with a single-level chain' do
      let!(:step) { create_step(order: 1, role: 'manager') }

      it 'approves the current step' do
        service.advance!(approver: manager)
        expect(step.reload.status).to eq('approved')
        expect(step.reload.approved_by).to eq(manager)
      end

      it 'returns true when chain is complete' do
        expect(service.advance!(approver: manager)).to be true
      end
    end

    context 'with a 2-level chain' do
      let!(:step1) { create_step(order: 1, role: 'manager') }
      let!(:step2) { create_step(order: 2, role: 'hr') }

      it 'approves step 1 and chain is not yet complete' do
        result = service.advance!(approver: manager)
        expect(result).to be false
        expect(step1.reload.status).to eq('approved')
        expect(step2.reload.status).to eq('pending')
      end

      it 'completes chain after step 2 approval' do
        service.advance!(approver: manager)
        result = service.advance!(approver: hr)
        expect(result).to be true
      end
    end

    context 'role enforcement' do
      let!(:step) { create_step(order: 1, role: 'hr') }

      it 'raises when employee role does not match required role' do
        expect { service.advance!(approver: manager) }.to raise_error(RuntimeError, /cannot approve/)
      end

      it 'allows admin to approve any step' do
        admin = create(:employee, organization: org, role: 'admin')
        expect { service.advance!(approver: admin) }.not_to raise_error
      end
    end

    it 'raises when no pending step exists' do
      expect { service.advance!(approver: manager) }.to raise_error(RuntimeError, /No pending/)
    end
  end

  describe '#reject!' do
    let!(:step) { create_step(order: 1, role: 'manager') }

    it 'rejects the current step' do
      service.reject!(approver: manager, comment: 'Période chargée')
      expect(step.reload.status).to eq('rejected')
      expect(step.reload.rejected_by).to eq(manager)
      expect(step.reload.comment).to eq('Période chargée')
    end

    it 'returns false' do
      expect(service.reject!(approver: manager)).to be false
    end

    it 'raises when approver role does not match required role' do
      expect { service.reject!(approver: hr) }.to raise_error(RuntimeError, /cannot reject/)
    end

    it 'allows admin to reject any step' do
      admin = create(:employee, organization: org, role: 'admin')
      expect { service.reject!(approver: admin) }.not_to raise_error
    end
  end

  describe '#summary' do
    it 'returns a human-readable summary' do
      create_step(order: 1, role: 'manager', status: 'approved')
      create_step(order: 2, role: 'hr')
      expect(service.summary).to eq('1/2 étapes approuvées')
    end
  end
end
