# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeavePolicyEngine, type: :service do
  let(:organization) { create(:organization, settings: { 'rtt_enabled' => true }) }
  let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
  let(:engine) { described_class.new(employee) }

  before do
    ActsAsTenant.current_tenant = organization
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe '#initialize' do
    it 'sets the employee' do
      expect(engine.employee).to eq(employee)
    end

    it 'sets the organization from employee' do
      expect(engine.organization).to eq(organization)
    end

    it 'initializes with a valid employee' do
      expect { described_class.new(employee) }.not_to raise_error
    end
  end

  describe '#get_setting' do
    context 'with legal defaults' do
      it 'returns cp_acquisition_rate default' do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(2.5)
      end

      it 'returns cp_max_annual default' do
        expect(engine.get_setting(:cp_max_annual)).to eq(30)
      end

      it 'returns cp_expiry_month default' do
        expect(engine.get_setting(:cp_expiry_month)).to eq(5)
      end

      it 'returns cp_expiry_day default' do
        expect(engine.get_setting(:cp_expiry_day)).to eq(31)
      end

      it 'returns minimum_consecutive_leave_days default' do
        expect(engine.get_setting(:minimum_consecutive_leave_days)).to eq(10)
      end

      it 'returns legal_work_week_hours default' do
        expect(engine.get_setting(:legal_work_week_hours)).to eq(35)
      end

      it 'returns rtt_calculation_threshold default' do
        expect(engine.get_setting(:rtt_calculation_threshold)).to eq(35)
      end

      it 'returns auto_approve_threshold_days default' do
        expect(engine.get_setting(:auto_approve_threshold_days)).to eq(15)
      end

      it 'returns auto_approve_max_request_days default' do
        expect(engine.get_setting(:auto_approve_max_request_days)).to eq(2)
      end

      it 'returns cp_acquisition_period_months default' do
        expect(engine.get_setting(:cp_acquisition_period_months)).to eq(12)
      end
    end

    context 'with organization override' do
      let(:organization) do
        create(:organization, settings: {
          'cp_acquisition_rate' => 3.0,
          'cp_max_annual' => 35,
          'rtt_enabled' => true
        })
      end

      it 'returns organization cp_acquisition_rate' do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(3.0)
      end

      it 'returns organization cp_max_annual' do
        expect(engine.get_setting(:cp_max_annual)).to eq(35)
      end

      it 'returns legal default for non-overridden settings' do
        expect(engine.get_setting(:cp_expiry_month)).to eq(5)
      end
    end

    context 'with employee contract override' do
      let(:employee) do
        create(:employee,
          organization: organization,
          start_date: 6.months.ago.to_date,
          contract_overrides: {
            'cp_acquisition_rate' => 3.5,
            'cp_max_annual' => 40
          })
      end

      it 'returns employee contract cp_acquisition_rate' do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(3.5)
      end

      it 'returns employee contract cp_max_annual' do
        expect(engine.get_setting(:cp_max_annual)).to eq(40)
      end
    end

    context 'with cascading priority (employee > org > legal)' do
      let(:organization) do
        create(:organization, settings: {
          'cp_acquisition_rate' => 3.0,
          'cp_max_annual' => 35,
          'rtt_enabled' => false
        })
      end

      let(:employee) do
        create(:employee,
          organization: organization,
          start_date: 6.months.ago.to_date,
          contract_overrides: {
            'cp_acquisition_rate' => 3.5
          })
      end

      it 'prioritizes employee contract override' do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(3.5)
      end

      it 'falls back to organization setting if not in employee contract' do
        expect(engine.get_setting(:cp_max_annual)).to eq(35)
      end

      it 'falls back to legal default if not in employee or organization' do
        expect(engine.get_setting(:cp_expiry_month)).to eq(5)
      end
    end
  end

  describe '#calculate_cp_balance' do
    context 'with new employee' do
      let(:employee) { create(:employee, organization: organization, start_date: Date.current) }

      it 'returns 0 days for 0 months' do
        expect(engine.calculate_cp_balance(as_of_date: Date.current)).to eq(0)
      end
    end

    context 'with 1 month tenure' do
      let(:employee) { create(:employee, organization: organization, start_date: 1.month.ago.to_date) }

      it 'returns 2.5 days' do
        expect(engine.calculate_cp_balance).to eq(2.5)
      end
    end

    context 'with 6 months tenure' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }

      it 'returns 15 days' do
        expect(engine.calculate_cp_balance).to eq(15.0)
      end
    end

    context 'with 12 months tenure' do
      let(:employee) { create(:employee, organization: organization, start_date: 12.months.ago.to_date) }

      it 'returns 30 days (maximum)' do
        expect(engine.calculate_cp_balance).to eq(30.0)
      end
    end

    context 'with 18 months tenure' do
      let(:employee) { create(:employee, organization: organization, start_date: 18.months.ago.to_date) }

      it 'returns 30 days (capped at maximum)' do
        expect(engine.calculate_cp_balance).to eq(30.0)
      end
    end

    context 'with 24 months tenure' do
      let(:employee) { create(:employee, organization: organization, start_date: 24.months.ago.to_date) }

      it 'returns 30 days (capped at maximum)' do
        expect(engine.calculate_cp_balance).to eq(30.0)
      end
    end

    context 'with part-time employee (24h/week)' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :part_time_24h, employee: employee) }

      it 'prorates CP balance based on weekly hours' do
        # 6 months * 2.5 days/month = 15 days
        # 24h/35h = 0.6857... ratio
        # 15 * 0.6857 = 10.29 days
        expect(engine.calculate_cp_balance).to be_within(0.01).of(10.29)
      end
    end

    context 'with part-time employee (28h/week)' do
      let(:employee) { create(:employee, organization: organization, start_date: 12.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :part_time_28h, employee: employee) }

      it 'prorates CP balance and respects maximum' do
        # 12 months * 2.5 = 30 days base
        # 28h/35h = 0.8 ratio
        # 30 * 0.8 = 24 days
        expect(engine.calculate_cp_balance).to eq(24.0)
      end
    end

    context 'with custom acquisition rate via organization' do
      let(:organization) do
        create(:organization, settings: {
          'cp_acquisition_rate' => 3.0,
          'cp_max_annual' => 36,
          'rtt_enabled' => true
        })
      end
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }

      it 'uses custom rate to calculate balance' do
        # 6 months * 3.0 days/month = 18 days
        expect(engine.calculate_cp_balance).to eq(18.0)
      end
    end

    context 'with custom maximum via organization' do
      let(:organization) do
        create(:organization, settings: {
          'cp_acquisition_rate' => 2.5,
          'cp_max_annual' => 25,
          'rtt_enabled' => true
        })
      end
      let(:employee) { create(:employee, organization: organization, start_date: 12.months.ago.to_date) }

      it 'caps at custom maximum' do
        # 12 months * 2.5 = 30, but max is 25
        expect(engine.calculate_cp_balance).to eq(25.0)
      end
    end

    context 'with specific calculation date' do
      let(:employee) { create(:employee, organization: organization, start_date: Date.new(2024, 1, 1)) }

      it 'calculates balance as of specific date' do
        # From Jan 1, 2024 to Jul 1, 2024 = 6 months
        as_of = Date.new(2024, 7, 1)
        expect(engine.calculate_cp_balance(as_of_date: as_of)).to eq(15.0)
      end

      it 'calculates different balance for different date' do
        # From Jan 1, 2024 to Oct 1, 2024 = 9 months
        as_of = Date.new(2024, 10, 1)
        expect(engine.calculate_cp_balance(as_of_date: as_of)).to eq(22.5)
      end
    end
  end

  describe '#calculate_rtt_accrual' do
    context 'when RTT is disabled' do
      let(:organization) { create(:organization, :with_rtt_disabled) }

      it 'returns 0 for any hours worked' do
        expect(engine.calculate_rtt_accrual(39)).to eq(0)
      end

      it 'returns 0 even for high overtime' do
        expect(engine.calculate_rtt_accrual(48)).to eq(0)
      end
    end

    context 'with exactly 35h/week' do
      it 'returns 0 RTT days (no overtime)' do
        expect(engine.calculate_rtt_accrual(35)).to eq(0)
      end
    end

    context 'with 39h/week (4h overtime)' do
      it 'accrues RTT based on overtime' do
        # 4 hours over 35h = 4/7 = ~0.571 RTT days per week
        rtt = engine.calculate_rtt_accrual(39, period_weeks: 1)
        expect(rtt).to be_within(0.01).of(0.57)
      end
    end

    context 'with 42h/week (7h overtime)' do
      it 'accrues 1 RTT day per week' do
        # 7 hours over 35h = 7/7 = 1 RTT day
        expect(engine.calculate_rtt_accrual(42, period_weeks: 1)).to eq(1.0)
      end
    end

    context 'with 48h/week (13h overtime - max legal)' do
      it 'accrues RTT based on maximum legal hours' do
        # 13 hours over 35h = 13/7 = ~1.857 RTT days
        rtt = engine.calculate_rtt_accrual(48, period_weeks: 1)
        expect(rtt).to be_within(0.01).of(1.86)
      end
    end

    context 'with multiple weeks calculation' do
      it 'calculates RTT for 4 weeks (1 month)' do
        # 39h/week = 4h overtime per week
        # 4h * 4 weeks = 16h total
        # 16h / 7 = ~2.286 RTT days
        rtt = engine.calculate_rtt_accrual(39 * 4, period_weeks: 4)
        expect(rtt).to be_within(0.01).of(2.29)
      end

      it 'calculates RTT for 52 weeks (1 year)' do
        # 39h/week = 4h overtime per week
        # 4h * 52 weeks = 208h total
        # 208h / 7 = ~29.71 RTT days
        rtt = engine.calculate_rtt_accrual(39 * 52, period_weeks: 52)
        expect(rtt).to be_within(0.1).of(29.71)
      end
    end

    context 'with part-time employee under 35h' do
      it 'returns 0 RTT (no overtime)' do
        # 24h/week, no overtime
        expect(engine.calculate_rtt_accrual(24)).to eq(0)
      end

      it 'returns 0 RTT for 28h/week' do
        expect(engine.calculate_rtt_accrual(28)).to eq(0)
      end
    end

    context 'with varying weekly hours' do
      it 'handles 37h/week (2h overtime)' do
        rtt = engine.calculate_rtt_accrual(37, period_weeks: 1)
        expect(rtt).to be_within(0.01).of(0.29)
      end

      it 'handles 40h/week (5h overtime)' do
        rtt = engine.calculate_rtt_accrual(40, period_weeks: 1)
        expect(rtt).to be_within(0.01).of(0.71)
      end

      it 'handles 44h/week (9h overtime)' do
        rtt = engine.calculate_rtt_accrual(44, period_weeks: 1)
        expect(rtt).to be_within(0.01).of(1.29)
      end
    end
  end

  describe '#validate_leave_request' do
    let!(:cp_balance) { create(:leave_balance, :cp, employee: employee, balance: 20.0) }

    context 'with insufficient balance' do
      let(:leave_request) { build(:leave_request, employee: employee, leave_type: 'CP', days_count: 25) }

      it 'returns error for insufficient balance' do
        errors = engine.validate_leave_request(leave_request)
        expect(errors).to include('Solde insuffisant pour CP')
      end
    end

    context 'with sufficient balance' do
      let(:leave_request) { build(:leave_request, employee: employee, leave_type: 'CP', days_count: 10) }

      it 'returns no balance error' do
        errors = engine.validate_leave_request(leave_request)
        expect(errors).not_to include(match(/Solde insuffisant/))
      end
    end

    context 'with summer consecutive leave requirement' do
      context 'when requesting less than 10 days in summer' do
        let(:leave_request) do
          build(:leave_request,
            employee: employee,
            leave_type: 'CP',
            start_date: Date.new(2025, 7, 1),
            end_date: Date.new(2025, 7, 5),
            days_count: 5)
        end

        it 'returns consecutive leave error' do
          errors = engine.validate_leave_request(leave_request)
          expect(errors).to include(match(/au moins 10 jours consécutifs/))
        end
      end

      context 'when requesting exactly 10 days in summer' do
        let(:leave_request) do
          build(:leave_request,
            employee: employee,
            leave_type: 'CP',
            start_date: Date.new(2025, 8, 1),
            end_date: Date.new(2025, 8, 10),
            days_count: 10)
        end

        it 'returns no consecutive leave error' do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
          errors = engine.validate_leave_request(leave_request)
          expect(errors).not_to include(match(/au moins 10 jours consécutifs/))
        end
      end

      context 'when requesting more than 10 days in summer' do
        let(:leave_request) do
          build(:leave_request,
            employee: employee,
            leave_type: 'CP',
            start_date: Date.new(2025, 6, 15),
            end_date: Date.new(2025, 6, 30),
            days_count: 15)
        end

        it 'returns no consecutive leave error' do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
          errors = engine.validate_leave_request(leave_request)
          expect(errors).not_to include(match(/au moins 10 jours consécutifs/))
        end
      end

      context 'when requesting leave outside summer period' do
        let(:leave_request) do
          build(:leave_request,
            employee: employee,
            leave_type: 'CP',
            start_date: Date.new(2025, 11, 1),
            end_date: Date.new(2025, 11, 3),
            days_count: 3)
        end

        it 'returns no consecutive leave error' do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
          errors = engine.validate_leave_request(leave_request)
          expect(errors).not_to include(match(/au moins 10 jours consécutifs/))
        end
      end
    end

    context 'with expired CP' do
      let!(:expired_balance) do
        cp_balance.update!(expires_at: 1.month.ago.to_date)
        cp_balance
      end
      let(:leave_request) { build(:leave_request, employee: employee, leave_type: 'CP', days_count: 5) }

      it 'returns expiration error' do
        errors = engine.validate_leave_request(leave_request)
        expect(errors).to include(match(/ont expiré/))
      end
    end

    context 'with team conflicts' do
      let(:leave_request) { build(:leave_request, employee: employee, leave_type: 'CP', days_count: 5) }

      before do
        allow(leave_request).to receive(:conflicts_with_team?).and_return(true)
      end

      it 'returns conflict error' do
        errors = engine.validate_leave_request(leave_request)
        expect(errors).to include('Conflit avec les congés d\'un autre membre de l\'équipe')
      end
    end

    context 'with multiple errors' do
      let(:leave_request) do
        build(:leave_request,
          employee: employee,
          leave_type: 'CP',
          start_date: Date.new(2025, 7, 1),
          end_date: Date.new(2025, 7, 5),
          days_count: 25)
      end

      before do
        allow(leave_request).to receive(:conflicts_with_team?).and_return(true)
      end

      it 'returns all applicable errors' do
        errors = engine.validate_leave_request(leave_request)
        expect(errors.size).to be >= 2
        expect(errors).to include(match(/Solde insuffisant/))
        expect(errors).to include(match(/Conflit avec les congés/))
      end
    end

    context 'with RTT leave type' do
      let!(:rtt_balance) { create(:leave_balance, :rtt, employee: employee, balance: 5.0) }
      let(:leave_request) { build(:leave_request, :rtt, employee: employee, days_count: 1) }

      it 'does not enforce consecutive leave requirement' do
        allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
        errors = engine.validate_leave_request(leave_request)
        expect(errors).not_to include(match(/au moins 10 jours consécutifs/))
      end
    end
  end

  describe '#calculate_working_days' do
    context 'with a regular week without holidays' do
      it 'returns 5 working days for Mon-Fri' do
        start_date = Date.new(2025, 1, 6) # Monday
        end_date = Date.new(2025, 1, 10) # Friday
        expect(engine.calculate_working_days(start_date, end_date)).to eq(5)
      end
    end

    context 'with weekend days' do
      it 'excludes Saturday and Sunday' do
        start_date = Date.new(2025, 1, 6) # Monday
        end_date = Date.new(2025, 1, 12) # Sunday
        expect(engine.calculate_working_days(start_date, end_date)).to eq(5)
      end

      it 'excludes only weekend for Sat-Sun period' do
        start_date = Date.new(2025, 1, 11) # Saturday
        end_date = Date.new(2025, 1, 12) # Sunday
        expect(engine.calculate_working_days(start_date, end_date)).to eq(0)
      end
    end

    context 'with French holidays' do
      it 'excludes New Year (Jan 1)' do
        start_date = Date.new(2024, 12, 30) # Monday
        end_date = Date.new(2025, 1, 2) # Thursday
        # Dec 30, 31, Jan 2 = 3 days (Jan 1 is holiday, Dec 31 is Tue)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(3)
      end

      it 'excludes Bastille Day (July 14)' do
        start_date = Date.new(2025, 7, 14) # Monday
        end_date = Date.new(2025, 7, 18) # Friday
        # Tue-Fri = 4 days (July 14 is holiday)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end

      it 'excludes Christmas (Dec 25)' do
        start_date = Date.new(2025, 12, 22) # Monday
        end_date = Date.new(2025, 12, 26) # Friday
        # Mon-Thu = 4 days (Dec 25 is holiday)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end

      it 'excludes May 1 (Labor Day)' do
        start_date = Date.new(2025, 4, 28) # Monday
        end_date = Date.new(2025, 5, 2) # Friday
        # Mon-Thu = 4 days (May 1 is holiday)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end

      it 'excludes May 8 (Victory Day)' do
        start_date = Date.new(2025, 5, 5) # Monday
        end_date = Date.new(2025, 5, 9) # Friday
        # Mon, Tue, Fri = 4 days (May 8 is holiday)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end
    end

    context 'with Easter-based holidays' do
      it 'excludes Easter Monday 2025 (April 21)' do
        start_date = Date.new(2025, 4, 21) # Monday (Easter Monday)
        end_date = Date.new(2025, 4, 25) # Friday
        # Tue-Fri = 4 days
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end

      it 'excludes Ascension Day 2025 (May 29)' do
        start_date = Date.new(2025, 5, 26) # Monday
        end_date = Date.new(2025, 5, 30) # Friday
        # Mon, Tue, Wed, Fri = 4 days (May 29 is Ascension)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end

      it 'excludes Whit Monday 2025 (June 9)' do
        start_date = Date.new(2025, 6, 9) # Monday (Whit Monday)
        end_date = Date.new(2025, 6, 13) # Friday
        # Tue-Fri = 4 days
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end
    end

    context 'with multiple holidays' do
      it 'excludes multiple holidays in November' do
        start_date = Date.new(2025, 10, 27) # Monday
        end_date = Date.new(2025, 11, 14) # Friday
        # Oct 27-31 = 5 days, Nov 3-7 = 5 days, Nov 10-14 = 5 days
        # Nov 1 (Sat) and Nov 11 (Tue) are holidays
        # Weekends: Nov 1-2, Nov 8-9
        working_days = engine.calculate_working_days(start_date, end_date)
        expect(working_days).to eq(14) # 19 days - 4 weekend days - 1 holiday (Nov 11, Nov 1 is Sat)
      end
    end

    context 'with full month calculation' do
      it 'calculates working days for January 2025' do
        start_date = Date.new(2025, 1, 1)
        end_date = Date.new(2025, 1, 31)
        # 31 days - 8 weekend days - 1 holiday (Jan 1) = 22 working days
        expect(engine.calculate_working_days(start_date, end_date)).to eq(22)
      end

      it 'calculates working days for August 2025' do
        start_date = Date.new(2025, 8, 1)
        end_date = Date.new(2025, 8, 31)
        # Aug 1 is Friday, Aug 15 is Friday (holiday)
        # 31 days - 10 weekend days (2,3,9,10,16,17,23,24,30,31) - 1 holiday (Aug 15) = 20 working days
        expect(engine.calculate_working_days(start_date, end_date)).to eq(20)
      end
    end

    context 'with single day' do
      it 'returns 1 for a working day' do
        date = Date.new(2025, 1, 13) # Monday
        expect(engine.calculate_working_days(date, date)).to eq(1)
      end

      it 'returns 0 for Saturday' do
        date = Date.new(2025, 1, 11) # Saturday
        expect(engine.calculate_working_days(date, date)).to eq(0)
      end

      it 'returns 0 for a holiday' do
        date = Date.new(2025, 7, 14) # Bastille Day
        expect(engine.calculate_working_days(date, date)).to eq(0)
      end
    end
  end

  describe 'French holiday calculations' do
    describe '#easter_sunday' do
      it 'calculates Easter Sunday for 2025' do
        easter = engine.send(:easter_sunday, 2025)
        expect(easter).to eq(Date.new(2025, 4, 20))
      end

      it 'calculates Easter Sunday for 2026' do
        easter = engine.send(:easter_sunday, 2026)
        expect(easter).to eq(Date.new(2026, 4, 5))
      end

      it 'calculates Easter Sunday for 2030' do
        easter = engine.send(:easter_sunday, 2030)
        expect(easter).to eq(Date.new(2030, 4, 21))
      end
    end

    describe '#easter_monday' do
      it 'returns day after Easter Sunday 2025' do
        easter_mon = engine.send(:easter_monday, 2025)
        expect(easter_mon).to eq(Date.new(2025, 4, 21))
      end

      it 'returns day after Easter Sunday 2026' do
        easter_mon = engine.send(:easter_monday, 2026)
        expect(easter_mon).to eq(Date.new(2026, 4, 6))
      end
    end

    describe '#ascension_day' do
      it 'returns Easter + 39 days for 2025' do
        ascension = engine.send(:ascension_day, 2025)
        expect(ascension).to eq(Date.new(2025, 5, 29))
      end

      it 'returns Easter + 39 days for 2026' do
        ascension = engine.send(:ascension_day, 2026)
        expect(ascension).to eq(Date.new(2026, 5, 14))
      end
    end

    describe '#whit_monday' do
      it 'returns Easter + 50 days for 2025' do
        whit = engine.send(:whit_monday, 2025)
        expect(whit).to eq(Date.new(2025, 6, 9))
      end

      it 'returns Easter + 50 days for 2026' do
        whit = engine.send(:whit_monday, 2026)
        expect(whit).to eq(Date.new(2026, 5, 25))
      end
    end

    describe '#french_holidays_for_year' do
      let(:holidays_2025) { engine.send(:french_holidays_for_year, 2025) }

      it 'includes all 11 French public holidays' do
        expect(holidays_2025.size).to eq(11)
      end

      it 'includes New Year' do
        expect(holidays_2025).to include(Date.new(2025, 1, 1))
      end

      it 'includes Easter Monday' do
        expect(holidays_2025).to include(Date.new(2025, 4, 21))
      end

      it 'includes Labor Day' do
        expect(holidays_2025).to include(Date.new(2025, 5, 1))
      end

      it 'includes Victory Day' do
        expect(holidays_2025).to include(Date.new(2025, 5, 8))
      end

      it 'includes Ascension Day' do
        expect(holidays_2025).to include(Date.new(2025, 5, 29))
      end

      it 'includes Whit Monday' do
        expect(holidays_2025).to include(Date.new(2025, 6, 9))
      end

      it 'includes Bastille Day' do
        expect(holidays_2025).to include(Date.new(2025, 7, 14))
      end

      it 'includes Assumption Day' do
        expect(holidays_2025).to include(Date.new(2025, 8, 15))
      end

      it 'includes All Saints Day' do
        expect(holidays_2025).to include(Date.new(2025, 11, 1))
      end

      it 'includes Armistice Day' do
        expect(holidays_2025).to include(Date.new(2025, 11, 11))
      end

      it 'includes Christmas' do
        expect(holidays_2025).to include(Date.new(2025, 12, 25))
      end
    end
  end

  describe '#can_auto_approve?' do
    let!(:cp_balance) { create(:leave_balance, :cp, employee: employee, balance: 20.0) }

    context 'with CP leave type' do
      context 'when all conditions met' do
        let(:leave_request) do
          create(:leave_request,
            employee: employee,
            leave_type: 'CP',
            days_count: 2,
            start_date: 1.week.from_now.to_date,
            end_date: (1.week.from_now + 1.day).to_date)
        end

        before do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
        end

        it 'returns true' do
          expect(engine.can_auto_approve?(leave_request)).to be true
        end
      end

      context 'with insufficient balance (< 15 days)' do
        let!(:low_balance) { cp_balance.update!(balance: 10.0) }
        let(:leave_request) { create(:leave_request, employee: employee, leave_type: 'CP', days_count: 2) }

        it 'returns false' do
          expect(engine.can_auto_approve?(leave_request)).to be false
        end
      end

      context 'with exactly threshold balance (15 days)' do
        let!(:threshold_balance) { cp_balance.update!(balance: 15.0) }
        let(:leave_request) do
          create(:leave_request,
            employee: employee,
            leave_type: 'CP',
            days_count: 2,
            start_date: 1.week.from_now.to_date,
            end_date: (1.week.from_now + 1.day).to_date)
        end

        before do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
        end

        it 'returns true' do
          expect(engine.can_auto_approve?(leave_request)).to be true
        end
      end

      context 'with long request (> 2 days)' do
        let(:leave_request) do
          create(:leave_request,
            employee: employee,
            leave_type: 'CP',
            days_count: 5,
            start_date: 1.week.from_now.to_date,
            end_date: (1.week.from_now + 4.days).to_date)
        end

        it 'returns false' do
          expect(engine.can_auto_approve?(leave_request)).to be false
        end
      end

      context 'with exactly max request days (2 days)' do
        let(:leave_request) do
          create(:leave_request,
            employee: employee,
            leave_type: 'CP',
            days_count: 2,
            start_date: 1.week.from_now.to_date,
            end_date: (1.week.from_now + 1.day).to_date)
        end

        before do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
        end

        it 'returns true' do
          expect(engine.can_auto_approve?(leave_request)).to be true
        end
      end

      context 'with team conflicts' do
        let(:leave_request) { create(:leave_request, employee: employee, leave_type: 'CP', days_count: 2) }

        before do
          allow(leave_request).to receive(:conflicts_with_team?).and_return(true)
        end

        it 'returns false' do
          expect(engine.can_auto_approve?(leave_request)).to be false
        end
      end
    end

    context 'with RTT leave type' do
      let!(:rtt_balance) { create(:leave_balance, :rtt, employee: employee, balance: 10.0) }
      let(:leave_request) { create(:leave_request, :rtt, employee: employee, days_count: 1) }

      it 'returns false (only CP can be auto-approved)' do
        expect(engine.can_auto_approve?(leave_request)).to be false
      end
    end

    context 'with other leave types' do
      let(:sick_leave) { create(:leave_request, :sick_leave, employee: employee, days_count: 1) }

      it 'returns false for sick leave' do
        expect(engine.can_auto_approve?(sick_leave)).to be false
      end
    end

    context 'with custom auto-approval settings' do
      let(:organization) do
        create(:organization, settings: {
          'auto_approve_threshold_days' => 20,
          'auto_approve_max_request_days' => 3,
          'rtt_enabled' => true
        })
      end
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let!(:cp_balance) { create(:leave_balance, :cp, employee: employee, balance: 22.0) }
      let(:leave_request) do
        create(:leave_request,
          employee: employee,
          leave_type: 'CP',
          days_count: 3,
          start_date: 1.week.from_now.to_date,
          end_date: (1.week.from_now + 2.days).to_date)
      end

      before do
        allow(leave_request).to receive(:conflicts_with_team?).and_return(false)
      end

      it 'uses custom thresholds' do
        expect(engine.can_auto_approve?(leave_request)).to be true
      end
    end
  end

  describe '#cp_expiration_date' do
    it 'returns May 31 of current year by default' do
      travel_to Date.new(2025, 1, 15) do
        expect(engine.cp_expiration_date).to eq(Date.new(2025, 5, 31))
      end
    end

    it 'returns May 31 of specified year' do
      expect(engine.cp_expiration_date(2026)).to eq(Date.new(2026, 5, 31))
    end

    it 'returns May 31 of next year when specified' do
      expect(engine.cp_expiration_date(2027)).to eq(Date.new(2027, 5, 31))
    end

    context 'with custom expiry settings' do
      let(:organization) do
        create(:organization, settings: {
          'cp_expiry_month' => 6,
          'cp_expiry_day' => 30,
          'rtt_enabled' => true
        })
      end

      it 'uses custom month and day' do
        expect(engine.cp_expiration_date).to eq(Date.new(Date.current.year, 6, 30))
      end
    end
  end

  describe '#accrue_monthly_cp!' do
    context 'when leave balance does not exist' do
      it 'creates a new CP balance' do
        expect {
          engine.accrue_monthly_cp!
        }.to change { employee.leave_balances.cp.count }.by(1)
      end

      it 'initializes balance with correct accrual amount' do
        accrual = engine.accrue_monthly_cp!
        balance = employee.leave_balances.cp.first
        expect(balance.balance).to eq(accrual)
      end

      it 'sets accrued_this_year to accrual amount' do
        accrual = engine.accrue_monthly_cp!
        balance = employee.leave_balances.cp.first
        expect(balance.accrued_this_year).to eq(accrual)
      end

      it 'sets expires_at to next May 31' do
        travel_to Date.new(2025, 1, 15) do
          engine.accrue_monthly_cp!
          balance = employee.leave_balances.cp.first
          expect(balance.expires_at).to eq(Date.new(2026, 5, 31))
        end
      end
    end

    context 'when leave balance exists' do
      let!(:cp_balance) { create(:leave_balance, :cp, employee: employee, balance: 10.0, accrued_this_year: 10.0) }

      it 'adds 2.5 days to existing balance' do
        expect {
          engine.accrue_monthly_cp!
        }.to change { cp_balance.reload.balance }.by(2.5)
      end

      it 'increments accrued_this_year' do
        expect {
          engine.accrue_monthly_cp!
        }.to change { cp_balance.reload.accrued_this_year }.by(2.5)
      end

      it 'updates expires_at to next year' do
        travel_to Date.new(2025, 3, 15) do
          engine.accrue_monthly_cp!
          expect(cp_balance.reload.expires_at).to eq(Date.new(2026, 5, 31))
        end
      end

      it 'returns the accrual amount' do
        accrual = engine.accrue_monthly_cp!
        expect(accrual).to eq(2.5)
      end
    end

    context 'with part-time employee (24h/week)' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :part_time_24h, employee: employee) }

      it 'prorates monthly accrual' do
        accrual = engine.accrue_monthly_cp!
        # 2.5 * (24/35) = 2.5 * 0.6857 = ~1.714
        expect(accrual).to be_within(0.01).of(1.71)
      end

      it 'adds prorated amount to balance' do
        cp_balance = create(:leave_balance, :cp, employee: employee, balance: 5.0, accrued_this_year: 5.0)
        engine.accrue_monthly_cp!
        expect(cp_balance.reload.balance).to be_within(0.01).of(6.71)
      end
    end

    context 'with custom acquisition rate' do
      let(:organization) do
        create(:organization, settings: {
          'cp_acquisition_rate' => 3.0,
          'rtt_enabled' => true
        })
      end

      it 'uses custom rate for accrual' do
        accrual = engine.accrue_monthly_cp!
        expect(accrual).to eq(3.0)
      end
    end
  end

  describe '#accrue_rtt!' do
    context 'when RTT is disabled' do
      let(:organization) { create(:organization, :with_rtt_disabled) }

      it 'returns 0' do
        accrual = engine.accrue_rtt!(39, period_weeks: 1)
        expect(accrual).to eq(0)
      end

      it 'does not create RTT balance' do
        expect {
          engine.accrue_rtt!(39, period_weeks: 1)
        }.not_to change { employee.leave_balances.rtt.count }
      end
    end

    context 'when RTT balance does not exist' do
      it 'creates a new RTT balance' do
        expect {
          engine.accrue_rtt!(39, period_weeks: 1)
        }.to change { employee.leave_balances.rtt.count }.by(1)
      end

      it 'initializes balance with correct accrual' do
        accrual = engine.accrue_rtt!(39, period_weeks: 1)
        balance = employee.leave_balances.rtt.first
        expect(balance.balance).to be_within(0.01).of(accrual)
      end

      it 'does not set expiration date for RTT' do
        engine.accrue_rtt!(39, period_weeks: 1)
        balance = employee.leave_balances.rtt.first
        expect(balance.expires_at).to be_nil
      end
    end

    context 'when RTT balance exists' do
      let!(:rtt_balance) { create(:leave_balance, :rtt, employee: employee, balance: 5.0, accrued_this_year: 5.0) }

      it 'adds RTT accrual to existing balance' do
        # 39h/week = 4h overtime = 4/7 = ~0.571 RTT days
        accrual = engine.accrue_rtt!(39, period_weeks: 1)
        expect(rtt_balance.reload.balance).to be_within(0.01).of(5.57)
      end

      it 'increments accrued_this_year' do
        initial_accrued = rtt_balance.accrued_this_year
        accrual = engine.accrue_rtt!(39, period_weeks: 1)
        expect(rtt_balance.reload.accrued_this_year).to be_within(0.01).of(initial_accrued + accrual)
      end

      it 'returns the accrual amount' do
        accrual = engine.accrue_rtt!(39, period_weeks: 1)
        expect(accrual).to be_within(0.01).of(0.57)
      end
    end

    context 'with exactly 35h/week' do
      it 'returns 0 and does not update balance' do
        rtt_balance = create(:leave_balance, :rtt, employee: employee, balance: 5.0)
        accrual = engine.accrue_rtt!(35, period_weeks: 1)
        expect(accrual).to eq(0)
        expect(rtt_balance.reload.balance).to eq(5.0)
      end
    end

    context 'with 48h/week for 4 weeks' do
      it 'accrues correct RTT amount' do
        # 48h/week = 13h overtime per week
        # 13h * 4 weeks = 52h total
        # 52h / 7 = ~7.43 RTT days
        accrual = engine.accrue_rtt!(48 * 4, period_weeks: 4)
        expect(accrual).to be_within(0.01).of(7.43)
      end
    end

    context 'with multiple accruals over time' do
      let!(:rtt_balance) { create(:leave_balance, :rtt, employee: employee, balance: 0, accrued_this_year: 0) }

      it 'accumulates RTT correctly' do
        # Week 1: 39h
        engine.accrue_rtt!(39, period_weeks: 1)
        expect(rtt_balance.reload.balance).to be_within(0.01).of(0.57)

        # Week 2: 42h
        engine.accrue_rtt!(42, period_weeks: 1)
        expect(rtt_balance.reload.balance).to be_within(0.01).of(1.57)

        # Week 3: 39h
        engine.accrue_rtt!(39, period_weeks: 1)
        expect(rtt_balance.reload.balance).to be_within(0.01).of(2.14)
      end
    end
  end

  describe 'part-time calculations' do
    context 'with 24h/week employee' do
      let(:employee) { create(:employee, organization: organization, start_date: 12.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :part_time_24h, employee: employee) }

      it 'calculates correct part-time ratio' do
        ratio = engine.send(:part_time_ratio)
        expect(ratio).to be_within(0.01).of(0.686)
      end

      it 'identifies as part-time employee' do
        expect(engine.send(:part_time_employee?)).to be true
      end

      it 'prorates CP balance' do
        # 12 months * 2.5 = 30 days base
        # 30 * (24/35) = 30 * 0.6857 = 20.57 days
        balance = engine.calculate_cp_balance
        expect(balance).to be_within(0.1).of(20.57)
      end

      it 'prorates monthly CP accrual' do
        accrual = engine.send(:monthly_cp_accrual)
        expect(accrual).to be_within(0.01).of(1.71)
      end

      it 'does not accrue RTT (under 35h)' do
        rtt = engine.calculate_rtt_accrual(24, period_weeks: 1)
        expect(rtt).to eq(0)
      end
    end

    context 'with 28h/week employee (4/5 time)' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :part_time_28h, employee: employee) }

      it 'calculates correct part-time ratio' do
        ratio = engine.send(:part_time_ratio)
        expect(ratio).to eq(0.8)
      end

      it 'prorates CP balance' do
        # 6 months * 2.5 = 15 days base
        # 15 * 0.8 = 12 days
        balance = engine.calculate_cp_balance
        expect(balance).to eq(12.0)
      end

      it 'does not accrue RTT' do
        rtt = engine.calculate_rtt_accrual(28, period_weeks: 1)
        expect(rtt).to eq(0)
      end
    end

    context 'with full-time 35h employee' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :full_time_35h, employee: employee) }

      it 'returns ratio of 1.0' do
        ratio = engine.send(:part_time_ratio)
        expect(ratio).to eq(1.0)
      end

      it 'is not identified as part-time' do
        expect(engine.send(:part_time_employee?)).to be false
      end

      it 'does not prorate CP balance' do
        balance = engine.calculate_cp_balance
        expect(balance).to eq(15.0)
      end
    end

    context 'with full-time 39h employee' do
      let(:employee) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let!(:work_schedule) { create(:work_schedule, :full_time_39h, employee: employee) }

      it 'is not identified as part-time' do
        expect(engine.send(:part_time_employee?)).to be false
      end

      it 'accrues RTT (over 35h)' do
        rtt = engine.calculate_rtt_accrual(39, period_weeks: 1)
        expect(rtt).to be_within(0.01).of(0.57)
      end

      it 'does not prorate CP balance' do
        balance = engine.calculate_cp_balance
        expect(balance).to eq(15.0)
      end
    end

    context 'with employee without work schedule' do
      let(:employee_no_schedule) { create(:employee, organization: organization, start_date: 6.months.ago.to_date) }
      let(:engine_no_schedule) { described_class.new(employee_no_schedule) }

      it 'returns ratio of 1.0 (defaults to full-time for CP calculation)' do
        ratio = engine_no_schedule.send(:part_time_ratio)
        expect(ratio).to eq(1.0)
      end

      it 'is identified as part-time (0 hours < 35)' do
        # When no work schedule, weekly_hours.to_f = 0, which is < 35
        expect(engine_no_schedule.send(:part_time_employee?)).to be true
      end

      it 'does not prorate CP balance (part_time_ratio returns 1.0 when no schedule)' do
        balance = engine_no_schedule.calculate_cp_balance
        expect(balance).to eq(15.0)
      end
    end
  end

  describe 'edge cases and boundary conditions' do
    context 'with employee starting on first day of month' do
      let(:employee) { create(:employee, organization: organization, start_date: Date.new(2024, 1, 1)) }

      it 'calculates correct months worked' do
        travel_to Date.new(2024, 7, 1) do
          expect(engine.calculate_cp_balance).to eq(15.0) # 6 months
        end
      end
    end

    context 'with employee starting on last day of month' do
      let(:employee) { create(:employee, organization: organization, start_date: Date.new(2024, 1, 31)) }

      it 'calculates correct months worked' do
        travel_to Date.new(2024, 7, 31) do
          expect(engine.calculate_cp_balance).to eq(15.0) # 6 months
        end
      end
    end

    context 'with leap year calculations' do
      it 'handles February 29 correctly' do
        start_date = Date.new(2024, 2, 29) # Leap year
        end_date = Date.new(2024, 3, 1)
        # Feb 29 is Thursday, Mar 1 is Friday = 2 working days
        expect(engine.calculate_working_days(start_date, end_date)).to eq(2)
      end
    end

    context 'with year-end boundary' do
      it 'handles December to January transition' do
        start_date = Date.new(2024, 12, 30) # Monday
        end_date = Date.new(2025, 1, 3) # Friday
        # Dec 30, 31, Jan 2, 3 = 4 days (Jan 1 is holiday, weekends excluded)
        expect(engine.calculate_working_days(start_date, end_date)).to eq(4)
      end
    end

    context 'with very long tenure' do
      let(:employee) { create(:employee, organization: organization, start_date: 10.years.ago.to_date) }

      it 'caps at maximum CP' do
        expect(engine.calculate_cp_balance).to eq(30.0)
      end
    end

    context 'with zero hours worked' do
      it 'returns 0 RTT accrual' do
        expect(engine.calculate_rtt_accrual(0)).to eq(0)
      end
    end

    context 'with fractional weeks' do
      it 'handles fractional week periods' do
        # 39h over 0.5 weeks = 4h overtime * 0.5 = 2h
        # 2h / 7 = ~0.286 RTT days
        rtt = engine.calculate_rtt_accrual(19.5, period_weeks: 0.5)
        expect(rtt).to be_within(0.01).of(0.29)
      end
    end
  end
end
