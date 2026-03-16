# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveBalanceSerializer do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org) }
  let(:balance)  { create(:leave_balance, :cp, employee: employee, balance: 12.5, expires_at: 3.months.from_now) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe '#as_json' do
    subject(:data) { described_class.new(balance).as_json }

    it 'includes all fields' do
      expect(data).to include(
        id:                balance.id,
        leave_type:        balance.leave_type,
        balance:           balance.balance,
        used_this_year:    balance.used_this_year,
        accrued_this_year: balance.accrued_this_year,
        expires_at:        balance.expires_at,
        expiring_soon:     balance.expiring_soon?
      )
    end

    it 'includes human-readable leave_type_name' do
      expect(data[:leave_type_name]).to be_present
    end

    context 'with a balance expiring soon' do
      let(:balance) { create(:leave_balance, :cp, employee: employee, balance: 5.0, expires_at: 1.month.from_now) }

      it 'flags expiring_soon as true' do
        expect(data[:expiring_soon]).to be true
      end
    end

    context 'with no expiry date' do
      let(:balance) { create(:leave_balance, :cp, employee: employee, balance: 5.0, expires_at: nil) }

      it 'returns nil for expires_at' do
        expect(data[:expires_at]).to be_nil
      end
    end
  end
end
