# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrganizationLeaveAccrualJob, type: :job do
  let(:org)      { create(:organization) }
  let!(:active)  { create(:employee, organization: org, start_date: 1.year.ago.to_date, end_date: nil) }
  let!(:inactive) do
    create(:employee, :inactive, organization: org,
           start_date: 2.years.ago.to_date, end_date: 1.month.ago.to_date)
  end

  describe '#perform' do
    it 'creates a CP balance for the active employee' do
      described_class.perform_now(org.id)

      ActsAsTenant.with_tenant(org) do
        balance = active.leave_balances.find_by(leave_type: 'CP')
        expect(balance).to be_present
        expect(balance.balance).to be > 0
      end
    end

    it 'does not create a balance for the inactive employee' do
      described_class.perform_now(org.id)

      ActsAsTenant.with_tenant(org) do
        balance = inactive.leave_balances.find_by(leave_type: 'CP')
        expect(balance).to be_nil
      end
    end

    it 'accumulates balance on repeated runs (additive accrual)' do
      ActsAsTenant.with_tenant(org) do
        described_class.perform_now(org.id)
        first_run_balance = active.reload.leave_balances.find_by(leave_type: 'CP').balance

        described_class.perform_now(org.id)
        second_run_balance = active.reload.leave_balances.find_by(leave_type: 'CP').balance

        expect(second_run_balance).to be > first_run_balance
      end
    end

    it 'discards the job when organization does not exist' do
      expect { described_class.perform_now(999_999) }.not_to raise_error
    end

    it 'runs on the accruals queue' do
      expect(described_class.new.queue_name).to eq('accruals')
    end

    it 'does not leak data across organizations' do
      other_org = create(:organization)
      other_emp = create(:employee, organization: other_org, start_date: 1.year.ago.to_date)

      described_class.perform_now(org.id)

      ActsAsTenant.with_tenant(other_org) do
        expect(other_emp.leave_balances.find_by(leave_type: 'CP')).to be_nil
      end
    end
  end
end
