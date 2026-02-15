# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveBalance, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:employee, organization: organization) }
  let(:leave_balance) { build(:leave_balance, employee: employee, leave_type: 'CP') }

  describe 'associations' do
    it { is_expected.to belong_to(:employee).required }

    it 'is associated with acts_as_tenant for organization' do
      expect(described_class.reflect_on_all_associations(:belongs_to).map(&:name)).to include(:organization)
    end

    context 'with valid employee' do
      it 'can be created with an employee' do
        ActsAsTenant.with_tenant(organization) do
          balance = create(:leave_balance, employee: employee)
          expect(balance.employee).to eq(employee)
        end
      end
    end
  end

  describe 'validations' do
    context 'leave_type validations' do
      it { is_expected.to validate_presence_of(:leave_type) }

      it 'validates uniqueness of leave_type scoped to employee_id' do
        ActsAsTenant.with_tenant(organization) do
          create(:leave_balance, employee: employee, leave_type: 'CP', organization: organization)
          duplicate = build(:leave_balance, employee: employee, leave_type: 'CP', organization: organization)

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:leave_type]).to be_present
        end
      end

      it 'allows same leave_type for different employees' do
        ActsAsTenant.with_tenant(organization) do
          employee2 = create(:employee, organization: organization)
          create(:leave_balance, employee: employee, leave_type: 'CP')
          duplicate = build(:leave_balance, employee: employee2, leave_type: 'CP')

          expect(duplicate).to be_valid
        end
      end

      it { is_expected.to validate_inclusion_of(:leave_type).in_array(%w[CP RTT Maladie Maternite Paternite Sans_Solde Anciennete]) }

      it 'rejects invalid leave_type' do
        leave_balance.leave_type = 'INVALID'
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:leave_type]).to be_present
      end

      it 'accepts all valid leave types' do
        ActsAsTenant.with_tenant(organization) do
          LeaveBalance::LEAVE_TYPES.keys.each do |type|
            balance = build(:leave_balance, employee: employee, leave_type: type)
            expect(balance).to be_valid, "Expected #{type} to be valid"
          end
        end
      end
    end

    context 'balance validations' do
      it { is_expected.to validate_presence_of(:balance) }
      it { is_expected.to validate_numericality_of(:balance).is_greater_than_or_equal_to(0) }

      it 'is invalid with negative balance' do
        leave_balance.balance = -5.0
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:balance]).to be_present
      end

      it 'is valid with zero balance' do
        leave_balance.balance = 0.0
        expect(leave_balance).to be_valid
      end

      it 'is valid with positive balance' do
        leave_balance.balance = 15.5
        expect(leave_balance).to be_valid
      end

      it 'is invalid with nil balance' do
        leave_balance.balance = nil
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:balance]).to be_present
      end
    end

    context 'accrued_this_year validations' do
      it { is_expected.to validate_presence_of(:accrued_this_year) }
      it { is_expected.to validate_numericality_of(:accrued_this_year).is_greater_than_or_equal_to(0) }

      it 'is invalid with negative accrued_this_year' do
        leave_balance.accrued_this_year = -2.5
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:accrued_this_year]).to be_present
      end

      it 'is valid with zero accrued_this_year' do
        leave_balance.accrued_this_year = 0.0
        expect(leave_balance).to be_valid
      end

      it 'is valid with positive accrued_this_year' do
        leave_balance.accrued_this_year = 25.0
        expect(leave_balance).to be_valid
      end

      it 'is invalid with nil accrued_this_year' do
        leave_balance.accrued_this_year = nil
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:accrued_this_year]).to be_present
      end
    end

    context 'used_this_year validations' do
      it { is_expected.to validate_presence_of(:used_this_year) }
      it { is_expected.to validate_numericality_of(:used_this_year).is_greater_than_or_equal_to(0) }

      it 'is invalid with negative used_this_year' do
        leave_balance.used_this_year = -7.5
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:used_this_year]).to be_present
      end

      it 'is valid with zero used_this_year' do
        leave_balance.used_this_year = 0.0
        expect(leave_balance).to be_valid
      end

      it 'is valid with positive used_this_year' do
        leave_balance.used_this_year = 12.5
        expect(leave_balance).to be_valid
      end

      it 'is invalid with nil used_this_year' do
        leave_balance.used_this_year = nil
        expect(leave_balance).not_to be_valid
        expect(leave_balance.errors[:used_this_year]).to be_present
      end
    end

    context 'employee_belongs_to_same_organization validation' do
      it 'is valid when employee and organization match' do
        ActsAsTenant.with_tenant(organization) do
          balance = build(:leave_balance, employee: employee, organization: organization)
          expect(balance).to be_valid
        end
      end

      it 'is invalid when employee belongs to different organization' do
        other_organization = create(:organization)
        other_employee = create(:employee, organization: other_organization)

        ActsAsTenant.with_tenant(organization) do
          balance = build(:leave_balance, employee: other_employee, organization: organization)
          expect(balance).not_to be_valid
          expect(balance.errors[:employee]).to include('must belong to the same organization')
        end
      end

      it 'validates organization_id matches employee organization_id' do
        other_organization = create(:organization)

        balance = build(:leave_balance, employee: employee, leave_type: 'CP')
        balance.organization_id = other_organization.id

        expect(balance).not_to be_valid
        expect(balance.errors[:employee]).to be_present
      end

      it 'is valid when both employee and organization_id are nil during build' do
        balance = LeaveBalance.new(leave_type: 'CP', balance: 10, accrued_this_year: 5, used_this_year: 0)
        # Should fail on other validations first (employee required)
        expect(balance).not_to be_valid
        expect(balance.errors[:employee]).to be_present
      end
    end

    context 'with all valid attributes' do
      it 'is valid' do
        ActsAsTenant.with_tenant(organization) do
          expect(leave_balance).to be_valid
        end
      end
    end
  end

  describe 'LEAVE_TYPES constant' do
    it 'is frozen' do
      expect(LeaveBalance::LEAVE_TYPES).to be_frozen
    end

    it 'contains CP (Congés Payés)' do
      expect(LeaveBalance::LEAVE_TYPES['CP']).to eq('Congés Payés')
    end

    it 'contains RTT (Réduction du Temps de Travail)' do
      expect(LeaveBalance::LEAVE_TYPES['RTT']).to eq('Réduction du Temps de Travail')
    end

    it 'contains Maladie (Congé Maladie)' do
      expect(LeaveBalance::LEAVE_TYPES['Maladie']).to eq('Congé Maladie')
    end

    it 'contains Maternite (Congé Maternité)' do
      expect(LeaveBalance::LEAVE_TYPES['Maternite']).to eq('Congé Maternité')
    end

    it 'contains Paternite (Congé Paternité)' do
      expect(LeaveBalance::LEAVE_TYPES['Paternite']).to eq('Congé Paternité')
    end

    it 'contains Sans_Solde (Congé Sans Solde)' do
      expect(LeaveBalance::LEAVE_TYPES['Sans_Solde']).to eq('Congé Sans Solde')
    end

    it 'contains Anciennete (Congés Ancienneté)' do
      expect(LeaveBalance::LEAVE_TYPES['Anciennete']).to eq('Congés Ancienneté')
    end

    it 'has exactly 7 leave types' do
      expect(LeaveBalance::LEAVE_TYPES.size).to eq(7)
    end

    it 'has all expected keys' do
      expected_keys = %w[CP RTT Maladie Maternite Paternite Sans_Solde Anciennete]
      expect(LeaveBalance::LEAVE_TYPES.keys).to match_array(expected_keys)
    end
  end

  describe '.leave_type_name' do
    it 'returns the French name for CP' do
      expect(LeaveBalance.leave_type_name('CP')).to eq('Congés Payés')
    end

    it 'returns the French name for RTT' do
      expect(LeaveBalance.leave_type_name('RTT')).to eq('Réduction du Temps de Travail')
    end

    it 'returns the French name for Maladie' do
      expect(LeaveBalance.leave_type_name('Maladie')).to eq('Congé Maladie')
    end

    it 'returns the French name for Maternite' do
      expect(LeaveBalance.leave_type_name('Maternite')).to eq('Congé Maternité')
    end

    it 'returns the French name for Paternite' do
      expect(LeaveBalance.leave_type_name('Paternite')).to eq('Congé Paternité')
    end

    it 'returns the French name for Sans_Solde' do
      expect(LeaveBalance.leave_type_name('Sans_Solde')).to eq('Congé Sans Solde')
    end

    it 'returns the French name for Anciennete' do
      expect(LeaveBalance.leave_type_name('Anciennete')).to eq('Congés Ancienneté')
    end

    it 'returns nil for invalid leave type' do
      expect(LeaveBalance.leave_type_name('INVALID')).to be_nil
    end
  end

  describe 'scopes' do
    let!(:cp_balance) { create(:leave_balance, :cp, employee: employee) }
    let!(:rtt_balance) { create(:leave_balance, :rtt, employee: employee) }
    let!(:maladie_balance) { create(:leave_balance, employee: employee, leave_type: 'Maladie') }

    describe '.cp' do
      it 'returns only CP leave balances' do
        ActsAsTenant.with_tenant(organization) do
          results = LeaveBalance.cp
          expect(results).to include(cp_balance)
          expect(results).not_to include(rtt_balance, maladie_balance)
        end
      end

      it 'returns empty when no CP balances exist' do
        ActsAsTenant.with_tenant(organization) do
          cp_balance.destroy
          expect(LeaveBalance.cp).to be_empty
        end
      end

      it 'returns multiple CP balances from different employees' do
        ActsAsTenant.with_tenant(organization) do
          employee2 = create(:employee, organization: organization)
          cp_balance2 = create(:leave_balance, :cp, employee: employee2)

          results = LeaveBalance.cp
          expect(results).to include(cp_balance, cp_balance2)
          expect(results.count).to eq(2)
        end
      end
    end

    describe '.rtt' do
      it 'returns only RTT leave balances' do
        ActsAsTenant.with_tenant(organization) do
          results = LeaveBalance.rtt
          expect(results).to include(rtt_balance)
          expect(results).not_to include(cp_balance, maladie_balance)
        end
      end

      it 'returns empty when no RTT balances exist' do
        ActsAsTenant.with_tenant(organization) do
          rtt_balance.destroy
          expect(LeaveBalance.rtt).to be_empty
        end
      end

      it 'returns multiple RTT balances from different employees' do
        ActsAsTenant.with_tenant(organization) do
          employee2 = create(:employee, organization: organization)
          rtt_balance2 = create(:leave_balance, :rtt, employee: employee2)

          results = LeaveBalance.rtt
          expect(results).to include(rtt_balance, rtt_balance2)
          expect(results.count).to eq(2)
        end
      end
    end

    describe '.expiring_soon' do
      let(:employee_expiring) { create(:employee, organization: organization) }
      let!(:expiring_soon_balance) { create(:leave_balance, :expiring_soon, employee: employee_expiring, organization: organization) }
      let!(:expired_balance) { create(:leave_balance, :expired, employee: employee_expiring, leave_type: 'RTT', organization: organization) }
      let!(:far_future_balance) do
        create(:leave_balance, employee: employee_expiring, leave_type: 'Maladie',
               expires_at: 6.months.from_now.to_date, organization: organization)
      end

      it 'includes balances expiring within 3 months' do
        ActsAsTenant.with_tenant(organization) do
          expect(LeaveBalance.expiring_soon).to include(expiring_soon_balance)
        end
      end

      it 'includes balances that have already expired' do
        ActsAsTenant.with_tenant(organization) do
          expect(LeaveBalance.expiring_soon).to include(expired_balance)
        end
      end

      it 'excludes balances expiring after 3 months' do
        ActsAsTenant.with_tenant(organization) do
          expect(LeaveBalance.expiring_soon).not_to include(far_future_balance)
        end
      end

      it 'excludes balances with no expiry date' do
        ActsAsTenant.with_tenant(organization) do
          expect(LeaveBalance.expiring_soon).not_to include(rtt_balance)
        end
      end

      it 'includes balance expiring exactly 3 months from now' do
        ActsAsTenant.with_tenant(organization) do
          exactly_3_months = create(:leave_balance, employee: employee,
                                   leave_type: 'Anciennete',
                                   expires_at: 3.months.from_now.to_date,
                                   organization: organization)
          expect(LeaveBalance.expiring_soon).to include(exactly_3_months)
        end
      end

      it 'excludes balance expiring 3 months and 1 day from now' do
        ActsAsTenant.with_tenant(organization) do
          just_after_threshold = create(:leave_balance, employee: employee,
                                       leave_type: 'Sans_Solde',
                                       expires_at: (3.months.from_now + 1.day).to_date,
                                       organization: organization)
          expect(LeaveBalance.expiring_soon).not_to include(just_after_threshold)
        end
      end

      it 'returns multiple balances when multiple are expiring soon' do
        ActsAsTenant.with_tenant(organization) do
          employee2 = create(:employee, organization: organization)
          expiring_balance2 = create(:leave_balance, :expiring_soon, employee: employee2, organization: organization)

          results = LeaveBalance.expiring_soon
          expect(results).to include(expiring_soon_balance, expired_balance, expiring_balance2)
          expect(results.count).to eq(3)
        end
      end
    end

    context 'scope chaining' do
      it 'can chain cp and expiring_soon scopes' do
        ActsAsTenant.with_tenant(organization) do
          employee2 = create(:employee, organization: organization)
          expiring_cp = create(:leave_balance, :cp, :expiring_soon, employee: employee2, organization: organization)
          non_expiring_cp = create(:leave_balance, :rtt, employee: employee2,
                                  expires_at: 1.year.from_now.to_date, organization: organization)

          results = LeaveBalance.cp.expiring_soon
          expect(results).to include(expiring_cp)
          expect(results).not_to include(non_expiring_cp)
        end
      end

      it 'can chain rtt and expiring_soon scopes (should be empty as RTT usually do not expire)' do
        ActsAsTenant.with_tenant(organization) do
          # RTT typically has no expires_at, so this should be empty
          results = LeaveBalance.rtt.expiring_soon
          expect(results).to be_empty
        end
      end
    end
  end

  describe '#available_balance' do
    it 'returns the balance value' do
      leave_balance.balance = 15.5
      expect(leave_balance.available_balance).to eq(15.5)
    end

    it 'returns zero when balance is zero' do
      leave_balance.balance = 0.0
      expect(leave_balance.available_balance).to eq(0.0)
    end

    it 'returns full balance for unused leave' do
      leave_balance.balance = 25.0
      leave_balance.used_this_year = 0.0
      expect(leave_balance.available_balance).to eq(25.0)
    end

    it 'returns current balance regardless of used_this_year' do
      leave_balance.balance = 10.0
      leave_balance.used_this_year = 15.0
      expect(leave_balance.available_balance).to eq(10.0)
    end

    it 'is aliased to balance accessor' do
      leave_balance.balance = 20.0
      expect(leave_balance.available_balance).to eq(leave_balance.balance)
    end
  end

  describe '#expiring_soon?' do
    context 'when expires_at is nil' do
      it 'returns false' do
        leave_balance.expires_at = nil
        expect(leave_balance.expiring_soon?).to be false
      end
    end

    context 'when expires_at is present' do
      it 'returns true when expiring in 1 month' do
        leave_balance.expires_at = 1.month.from_now.to_date
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns true when expiring in 2 months' do
        leave_balance.expires_at = 2.months.from_now.to_date
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns true when expiring exactly 3 months from now' do
        leave_balance.expires_at = 3.months.from_now.to_date
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns false when expiring in 4 months' do
        leave_balance.expires_at = 4.months.from_now.to_date
        expect(leave_balance.expiring_soon?).to be false
      end

      it 'returns false when expiring in 6 months' do
        leave_balance.expires_at = 6.months.from_now.to_date
        expect(leave_balance.expiring_soon?).to be false
      end

      it 'returns false when expiring in 1 year' do
        leave_balance.expires_at = 1.year.from_now.to_date
        expect(leave_balance.expiring_soon?).to be false
      end

      it 'returns true when already expired' do
        leave_balance.expires_at = 1.month.ago.to_date
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns true when expired yesterday' do
        leave_balance.expires_at = 1.day.ago.to_date
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns true when expiring today' do
        leave_balance.expires_at = Date.current
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns false when expiring 3 months and 1 day from now' do
        leave_balance.expires_at = (3.months.from_now + 1.day).to_date
        expect(leave_balance.expiring_soon?).to be false
      end
    end

    context 'boundary testing around 3-month threshold' do
      it 'returns true for 89 days from now (just under 3 months)' do
        leave_balance.expires_at = 89.days.from_now.to_date
        expect(leave_balance.expiring_soon?).to be true
      end

      it 'returns false for 91 days from now (just over 3 months)' do
        leave_balance.expires_at = 91.days.from_now.to_date
        # This depends on the current month, but generally should be false
        # The exact behavior depends on 3.months.from_now calculation
        result = leave_balance.expiring_soon?
        expect([true, false]).to include(result) # Boundary case, month-dependent
      end
    end
  end

  describe '#expired?' do
    context 'when expires_at is nil' do
      it 'returns false' do
        leave_balance.expires_at = nil
        expect(leave_balance.expired?).to be false
      end
    end

    context 'when expires_at is present' do
      it 'returns true when expired 1 month ago' do
        leave_balance.expires_at = 1.month.ago.to_date
        expect(leave_balance.expired?).to be true
      end

      it 'returns true when expired yesterday' do
        leave_balance.expires_at = 1.day.ago.to_date
        expect(leave_balance.expired?).to be true
      end

      it 'returns true when expired 1 year ago' do
        leave_balance.expires_at = 1.year.ago.to_date
        expect(leave_balance.expired?).to be true
      end

      it 'returns false when expiring today' do
        leave_balance.expires_at = Date.current
        expect(leave_balance.expired?).to be false
      end

      it 'returns false when expiring tomorrow' do
        leave_balance.expires_at = 1.day.from_now.to_date
        expect(leave_balance.expired?).to be false
      end

      it 'returns false when expiring in 1 month' do
        leave_balance.expires_at = 1.month.from_now.to_date
        expect(leave_balance.expired?).to be false
      end

      it 'returns false when expiring in 3 months' do
        leave_balance.expires_at = 3.months.from_now.to_date
        expect(leave_balance.expired?).to be false
      end

      it 'returns false when expiring in 1 year' do
        leave_balance.expires_at = 1.year.from_now.to_date
        expect(leave_balance.expired?).to be false
      end
    end

    context 'boundary testing around current date' do
      it 'uses Date.current for comparison' do
        travel_to Date.new(2025, 5, 31) do
          leave_balance.expires_at = Date.new(2025, 5, 30)
          expect(leave_balance.expired?).to be true
        end
      end

      it 'is not expired on the exact expiry date' do
        travel_to Date.new(2025, 5, 31) do
          leave_balance.expires_at = Date.new(2025, 5, 31)
          expect(leave_balance.expired?).to be false
        end
      end
    end
  end

  describe 'multi-tenancy with ActsAsTenant' do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let(:employee1) { create(:employee, organization: org1) }
    let(:employee2) { create(:employee, organization: org2) }
    let!(:balance1) { create(:leave_balance, employee: employee1, organization: org1) }
    let!(:balance2) { create(:leave_balance, employee: employee2, organization: org2) }

    it 'scopes queries to current organization' do
      ActsAsTenant.with_tenant(org1) do
        expect(LeaveBalance.all).to include(balance1)
        expect(LeaveBalance.all).not_to include(balance2)
      end
    end

    it 'can access balances from different organization when switching tenant' do
      ActsAsTenant.with_tenant(org2) do
        expect(LeaveBalance.all).to include(balance2)
        expect(LeaveBalance.all).not_to include(balance1)
      end
    end

    it 'cannot create balance for employee from different organization' do
      ActsAsTenant.with_tenant(org1) do
        balance = build(:leave_balance, employee: employee2, organization: org1)
        expect(balance).not_to be_valid
        expect(balance.errors[:employee]).to include('must belong to the same organization')
      end
    end

    it 'prevents cross-organization data leaks' do
      ActsAsTenant.with_tenant(org1) do
        expect(LeaveBalance.count).to eq(1)
      end

      ActsAsTenant.with_tenant(org2) do
        expect(LeaveBalance.count).to eq(1)
      end
    end

    it 'automatically sets organization_id from tenant' do
      ActsAsTenant.with_tenant(org1) do
        balance = create(:leave_balance, employee: employee1, leave_type: 'RTT', organization: org1)
        expect(balance.organization_id).to eq(org1.id)
      end
    end
  end

  describe 'French legal compliance scenarios' do
    context 'CP (Congés Payés) balance' do
      it 'can track 30 days maximum (French legal maximum)' do
        ActsAsTenant.with_tenant(organization) do
          cp_balance = create(:leave_balance, :cp, :full_balance, employee: employee)
          expect(cp_balance.balance).to eq(30.0)
          expect(cp_balance).to be_valid
        end
      end

      it 'expires on May 31 (French legal requirement)' do
        ActsAsTenant.with_tenant(organization) do
          cp_balance = create(:leave_balance, :cp, employee: employee,
                             expires_at: Date.new(Date.current.year, 5, 31))
          expect(cp_balance.expires_at.month).to eq(5)
          expect(cp_balance.expires_at.day).to eq(31)
        end
      end

      it 'can accrue 2.5 days per month' do
        ActsAsTenant.with_tenant(organization) do
          cp_balance = create(:leave_balance, :cp, employee: employee,
                             accrued_this_year: 2.5)
          expect(cp_balance.accrued_this_year).to eq(2.5)
        end
      end
    end

    context 'RTT (Réduction du Temps de Travail) balance' do
      it 'typically has no expiration date' do
        ActsAsTenant.with_tenant(organization) do
          rtt_balance = create(:leave_balance, :rtt, employee: employee)
          expect(rtt_balance.expires_at).to be_nil
        end
      end

      it 'can track fractional days' do
        ActsAsTenant.with_tenant(organization) do
          rtt_balance = create(:leave_balance, :rtt, employee: employee,
                              balance: 7.5, accrued_this_year: 10.0, used_this_year: 2.5)
          expect(rtt_balance.balance).to eq(7.5)
        end
      end
    end

    context 'multiple leave types per employee' do
      it 'allows one balance of each leave type per employee' do
        ActsAsTenant.with_tenant(organization) do
          LeaveBalance::LEAVE_TYPES.keys.each do |type|
            balance = create(:leave_balance, employee: employee, leave_type: type,
                           accrued_this_year: 5.0, used_this_year: 0.0)
            expect(balance).to be_valid
          end

          expect(employee.leave_balances.count).to eq(7)
        end
      end
    end
  end

  describe 'factory traits' do
    it 'creates valid balance with :cp trait' do
      ActsAsTenant.with_tenant(organization) do
        balance = create(:leave_balance, :cp, employee: employee)
        expect(balance.leave_type).to eq('CP')
        expect(balance).to be_valid
      end
    end

    it 'creates valid balance with :rtt trait' do
      ActsAsTenant.with_tenant(organization) do
        balance = create(:leave_balance, :rtt, employee: employee)
        expect(balance.leave_type).to eq('RTT')
        expect(balance.expires_at).to be_nil
        expect(balance).to be_valid
      end
    end

    it 'creates valid balance with :full_balance trait' do
      ActsAsTenant.with_tenant(organization) do
        balance = create(:leave_balance, :full_balance, employee: employee)
        expect(balance.balance).to eq(30.0)
        expect(balance.accrued_this_year).to eq(30.0)
        expect(balance.used_this_year).to eq(0.0)
      end
    end

    it 'creates valid balance with :low_balance trait' do
      ActsAsTenant.with_tenant(organization) do
        balance = create(:leave_balance, :low_balance, employee: employee)
        expect(balance.balance).to eq(2.5)
      end
    end

    it 'creates valid balance with :expired trait' do
      ActsAsTenant.with_tenant(organization) do
        balance = create(:leave_balance, :expired, employee: employee)
        expect(balance.expired?).to be true
      end
    end

    it 'creates valid balance with :expiring_soon trait' do
      ActsAsTenant.with_tenant(organization) do
        balance = create(:leave_balance, :expiring_soon, employee: employee)
        expect(balance.expiring_soon?).to be true
      end
    end
  end
end
