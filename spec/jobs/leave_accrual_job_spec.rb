# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveAccrualJob, type: :job do
  let(:org1) { create(:organization, name: 'Acme Corp') }
  let(:org2) { create(:organization, name: 'TechStart Inc') }

  let!(:employee1) { create(:employee, organization: org1, start_date: 1.year.ago.to_date) }
  let!(:employee2) { create(:employee, organization: org2, start_date: 6.months.ago.to_date) }
  let!(:inactive_employee) { create(:employee, :inactive, organization: org1, end_date: 1.month.ago.to_date) }

  describe '#perform' do
    it 'processes all organizations' do
      expect do
        described_class.perform_now
      end.to change { LeaveBalance.count }.by(2)
    end

    it 'creates CP balance for active employees' do
      described_class.perform_now

      ActsAsTenant.with_tenant(org1) do
        balance = employee1.leave_balances.find_by(leave_type: 'CP')
        expect(balance).to be_present
        expect(balance.balance).to eq(2.5)
      end

      ActsAsTenant.with_tenant(org2) do
        balance = employee2.leave_balances.find_by(leave_type: 'CP')
        expect(balance).to be_present
        expect(balance.balance).to eq(2.5)
      end
    end

    it 'does not process inactive employees' do
      described_class.perform_now

      ActsAsTenant.with_tenant(org1) do
        balance = inactive_employee.leave_balances.find_by(leave_type: 'CP')
        expect(balance).to be_nil
      end
    end

    it 'increments existing CP balance' do
      ActsAsTenant.with_tenant(org1) do
        create(:leave_balance, employee: employee1, organization: org1,
               leave_type: 'CP', balance: 10.0, accrued_this_year: 10.0)
      end

      described_class.perform_now

      ActsAsTenant.with_tenant(org1) do
        balance = employee1.leave_balances.find_by(leave_type: 'CP')
        expect(balance.balance).to eq(12.5)
        expect(balance.accrued_this_year).to eq(12.5)
      end
    end

    it 'respects max annual cap (30 days)' do
      ActsAsTenant.with_tenant(org1) do
        create(:leave_balance, employee: employee1, organization: org1,
               leave_type: 'CP', balance: 28.0, accrued_this_year: 28.0)
      end

      described_class.perform_now

      ActsAsTenant.with_tenant(org1) do
        balance = employee1.leave_balances.find_by(leave_type: 'CP')
        # Should cap at 30, so only +2 days instead of +2.5
        expect(balance.balance).to eq(30.0)
      end
    end

    it 'sets expiration date to May 31 next year' do
      described_class.perform_now

      ActsAsTenant.with_tenant(org1) do
        balance = employee1.leave_balances.find_by(leave_type: 'CP')
        expected_date = Date.new(Date.current.year + 1, 5, 31)
        expect(balance.expires_at).to eq(expected_date)
      end
    end

    it 'handles errors gracefully for one organization' do
      allow_any_instance_of(Employee).to receive(:leave_balances).and_raise(StandardError.new('DB error'))

      expect do
        described_class.perform_now
      end.not_to raise_error
    end
  end

  describe 'multi-tenant execution' do
    it 'maintains tenant isolation during processing' do
      described_class.perform_now

      ActsAsTenant.with_tenant(org1) do
        expect(LeaveBalance.count).to eq(1)
        expect(LeaveBalance.first.employee).to eq(employee1)
      end

      ActsAsTenant.with_tenant(org2) do
        expect(LeaveBalance.count).to eq(1)
        expect(LeaveBalance.first.employee).to eq(employee2)
      end
    end
  end
end
