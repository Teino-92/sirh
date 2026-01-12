# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveManagement::Services::LeavePolicyEngine do
  let(:organization) { create(:organization) }
  let(:employee) { create(:employee, organization: organization, start_date: 2.years.ago.to_date) }
  let(:engine) { described_class.new(employee) }

  before do
    ActsAsTenant.current_tenant = organization
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe '#get_setting' do
    context 'with default legal values' do
      it 'returns CP acquisition rate from legal defaults' do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(2.5)
      end

      it 'returns CP max annual from legal defaults' do
        expect(engine.get_setting(:cp_max_annual)).to eq(30)
      end

      it 'returns CP expiry month (May = 5)' do
        expect(engine.get_setting(:cp_expiry_month)).to eq(5)
      end

      it 'returns CP expiry day (31)' do
        expect(engine.get_setting(:cp_expiry_day)).to eq(31)
      end
    end

    context 'with organization settings override' do
      let(:organization) do
        create(:organization, settings: { 'cp_acquisition_rate' => 3.0, 'cp_max_annual' => 35 })
      end

      it 'uses organization setting over legal default' do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(3.0)
      end

      it 'uses organization max_annual override' do
        expect(engine.get_setting(:cp_max_annual)).to eq(35)
      end

      it 'falls back to legal default for unset values' do
        expect(engine.get_setting(:cp_expiry_month)).to eq(5)
      end
    end
  end

  describe '#calculate_cp_balance' do
    context 'for employee working 2 years' do
      it 'calculates correct accrual (2.5 days/month * 24 months)' do
        expect(engine.calculate_cp_balance).to eq(30.0)
      end
    end

    context 'for employee working 6 months' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }

      it 'calculates correct accrual (2.5 days/month * 6 months)' do
        expect(engine.calculate_cp_balance).to eq(15.0)
      end
    end

    context 'with max annual cap' do
      let(:employee) { create(:employee, organization: organization, start_date: 10.years.ago.to_date) }

      it 'caps at 30 days maximum' do
        expect(engine.calculate_cp_balance).to eq(30.0)
      end
    end
  end

  describe '#calculate_rtt_accrual' do
    context 'when RTT is enabled' do
      it 'returns 0 for exactly 35 hours' do
        expect(engine.calculate_rtt_accrual(35.0, period_weeks: 1)).to eq(0)
      end

      it 'calculates RTT for 42 hours (7 hours overtime = 1 day)' do
        expect(engine.calculate_rtt_accrual(42.0, period_weeks: 1)).to eq(1.0)
      end

      it 'calculates RTT for 38.5 hours (3.5 hours overtime = 0.5 days)' do
        expect(engine.calculate_rtt_accrual(38.5, period_weeks: 1)).to eq(0.5)
      end

      it 'returns 0 for less than 35 hours' do
        expect(engine.calculate_rtt_accrual(30.0, period_weeks: 1)).to eq(0)
      end
    end

    context 'when RTT is disabled' do
      let(:organization) { create(:organization, :with_rtt_disabled) }

      it 'returns 0 regardless of hours' do
        expect(engine.calculate_rtt_accrual(42.0, period_weeks: 1)).to eq(0)
      end
    end
  end

  describe '#calculate_working_days' do
    it 'excludes weekends' do
      # Monday to Friday = 5 days (Jan 5-9, 2026)
      start_date = Date.new(2026, 1, 5)  # Monday
      end_date = Date.new(2026, 1, 9)    # Friday
      expect(engine.calculate_working_days(start_date, end_date)).to eq(5)
    end

    it 'excludes French holidays (Jan 1st)' do
      # Dec 31 2025 to Jan 2 2026 = 3 days, minus Jan 1 (holiday) = 2 days
      start_date = Date.new(2025, 12, 31) # Wednesday
      end_date = Date.new(2026, 1, 2)     # Friday
      expect(engine.calculate_working_days(start_date, end_date)).to eq(2)
    end

    it 'excludes Bastille Day (July 14)' do
      # July 11-15 2026 = 5 days, minus weekend (12-13) and July 14 = 2 days
      start_date = Date.new(2026, 7, 13) # Monday
      end_date = Date.new(2026, 7, 15)   # Wednesday
      expect(engine.calculate_working_days(start_date, end_date)).to eq(2)
    end
  end

  describe '#french_holiday?' do
    it 'recognizes fixed French holidays' do
      expect(engine.send(:french_holiday?, Date.new(2026, 1, 1))).to be true   # New Year
      expect(engine.send(:french_holiday?, Date.new(2026, 5, 1))).to be true   # Labor Day
      expect(engine.send(:french_holiday?, Date.new(2026, 7, 14))).to be true  # Bastille Day
      expect(engine.send(:french_holiday?, Date.new(2026, 12, 25))).to be true # Christmas
    end

    it 'recognizes Easter Monday (movable holiday)' do
      # Easter Sunday 2026 = April 5, Monday = April 6
      expect(engine.send(:french_holiday?, Date.new(2026, 4, 6))).to be true
    end

    it 'does not recognize non-holidays' do
      expect(engine.send(:french_holiday?, Date.new(2026, 3, 15))).to be false
    end
  end

  describe '#easter_sunday' do
    it 'calculates Easter Sunday 2026 correctly' do
      expect(engine.send(:easter_sunday, 2026)).to eq(Date.new(2026, 4, 5))
    end

    it 'calculates Easter Sunday 2025 correctly' do
      expect(engine.send(:easter_sunday, 2025)).to eq(Date.new(2025, 4, 20))
    end
  end

  describe '#cp_expiration_date' do
    it 'returns May 31 of current year by default' do
      expect(engine.cp_expiration_date).to eq(Date.new(Date.current.year, 5, 31))
    end

    it 'returns May 31 of specified year' do
      expect(engine.cp_expiration_date(2027)).to eq(Date.new(2027, 5, 31))
    end
  end

  describe '#accrue_monthly_cp!' do
    it 'creates CP balance if it does not exist' do
      expect do
        engine.accrue_monthly_cp!
      end.to change { LeaveBalance.count }.by(1)
    end

    it 'adds 2.5 days to balance' do
      engine.accrue_monthly_cp!
      balance = employee.leave_balances.find_by(leave_type: 'CP')
      expect(balance.balance).to eq(2.5)
    end

    it 'increments accrued_this_year' do
      engine.accrue_monthly_cp!
      engine.accrue_monthly_cp!
      balance = employee.leave_balances.find_by(leave_type: 'CP')
      expect(balance.accrued_this_year).to eq(5.0)
    end

    it 'sets expiration to May 31 next year' do
      engine.accrue_monthly_cp!
      balance = employee.leave_balances.find_by(leave_type: 'CP')
      expect(balance.expires_at).to eq(Date.new(Date.current.year + 1, 5, 31))
    end
  end

  describe '#accrue_rtt!' do
    context 'when RTT enabled and overtime worked' do
      it 'creates RTT balance if it does not exist' do
        expect do
          engine.accrue_rtt!(42.0, period_weeks: 1)
        end.to change { LeaveBalance.where(leave_type: 'RTT').count }.by(1)
      end

      it 'adds 1 day for 7 hours overtime' do
        engine.accrue_rtt!(42.0, period_weeks: 1)
        balance = employee.leave_balances.find_by(leave_type: 'RTT')
        expect(balance.balance).to eq(1.0)
      end

      it 'accumulates RTT over multiple weeks' do
        engine.accrue_rtt!(42.0, period_weeks: 1)
        engine.accrue_rtt!(38.5, period_weeks: 1)
        balance = employee.leave_balances.find_by(leave_type: 'RTT')
        expect(balance.balance).to eq(1.5)
      end
    end

    context 'when no overtime' do
      it 'returns 0 for exactly 35 hours' do
        expect(engine.accrue_rtt!(35.0, period_weeks: 1)).to eq(0)
      end

      it 'returns 0 for less than 35 hours' do
        expect(engine.accrue_rtt!(30.0, period_weeks: 1)).to eq(0)
      end
    end

    context 'when RTT disabled' do
      let(:organization) { create(:organization, :with_rtt_disabled) }

      it 'returns 0' do
        expect(engine.accrue_rtt!(42.0, period_weeks: 1)).to eq(0)
      end
    end
  end
end
