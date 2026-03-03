# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Employee, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { build(:employee, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:manager).class_name('Employee').optional }
    it { is_expected.to have_many(:direct_reports).class_name('Employee').with_foreign_key(:manager_id).dependent(:nullify) }
    it { is_expected.to have_many(:leave_balances).dependent(:destroy) }
    it { is_expected.to have_many(:leave_requests).dependent(:destroy) }
    it { is_expected.to have_many(:time_entries).dependent(:destroy) }
    it { is_expected.to have_one(:work_schedule).dependent(:destroy) }
    it { is_expected.to have_many(:weekly_schedule_plans).dependent(:destroy) }
    it { is_expected.to have_many(:notifications).dependent(:destroy) }
    it { is_expected.to have_many(:approved_leave_requests).class_name('LeaveRequest').with_foreign_key(:approved_by_id) }
    it { is_expected.to have_one_attached(:avatar) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:contract_type) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:role) }

    it { is_expected.to validate_inclusion_of(:role).in_array(%w[employee manager hr admin]) }
    it { is_expected.to validate_inclusion_of(:contract_type).in_array(%w[CDI CDD Stage Alternance Interim]) }

    context 'with valid attributes' do
      it 'is valid' do
        expect(employee).to be_valid
      end
    end

    context 'with missing first_name' do
      it 'is invalid' do
        employee.first_name = nil
        expect(employee).not_to be_valid
        expect(employee.errors[:first_name]).to be_present
      end
    end

    context 'with missing last_name' do
      it 'is invalid' do
        employee.last_name = nil
        expect(employee).not_to be_valid
        expect(employee.errors[:last_name]).to be_present
      end
    end

    context 'with invalid role' do
      it 'is invalid' do
        employee.role = 'invalid_role'
        expect(employee).not_to be_valid
        expect(employee.errors[:role]).to be_present
      end
    end

    context 'with invalid contract_type' do
      it 'is invalid' do
        employee.contract_type = 'invalid_contract'
        expect(employee).not_to be_valid
        expect(employee.errors[:contract_type]).to be_present
      end
    end

    context 'with missing start_date' do
      it 'is invalid' do
        employee.start_date = nil
        expect(employee).not_to be_valid
        expect(employee.errors[:start_date]).to be_present
      end
    end

    describe 'email validations' do
      it 'requires a valid email format' do
        employee.email = 'invalid_email'
        expect(employee).not_to be_valid
      end

      it 'requires unique email' do
        create(:employee, email: 'test@example.com', organization: organization)
        duplicate_employee = build(:employee, email: 'test@example.com', organization: organization)
        expect(duplicate_employee).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_employee) { create(:employee, organization: organization, settings: { active: true }) }
    let!(:inactive_employee) { create(:employee, :inactive, organization: organization) }
    let!(:manager) { create(:employee, :manager, organization: organization) }
    let!(:hr_user) { create(:employee, :hr, organization: organization) }
    let!(:admin_user) { create(:employee, :admin, organization: organization) }
    let!(:engineering_employee) { create(:employee, organization: organization, department: 'Engineering') }
    let!(:sales_employee) { create(:employee, organization: organization, department: 'Sales') }

    describe '.active' do
      it 'returns only active employees' do
        ActsAsTenant.with_tenant(organization) do
          expect(Employee.active).to include(active_employee)
          expect(Employee.active).not_to include(inactive_employee)
        end
      end
    end

    describe '.managers' do
      it 'returns employees with manager, hr, or admin roles' do
        ActsAsTenant.with_tenant(organization) do
          managers = Employee.managers
          expect(managers).to include(manager, hr_user, admin_user)
          expect(managers).not_to include(active_employee)
        end
      end
    end

    describe '.by_department' do
      it 'returns employees from specified department' do
        ActsAsTenant.with_tenant(organization) do
          expect(Employee.by_department('Engineering')).to include(engineering_employee)
          expect(Employee.by_department('Engineering')).not_to include(sales_employee)
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#full_name' do
      it 'returns the concatenated first and last name' do
        employee.first_name = 'Jean'
        employee.last_name = 'Dupont'
        expect(employee.full_name).to eq('Jean Dupont')
      end
    end

    describe '#manager?' do
      it 'returns true for manager role' do
        employee.role = 'manager'
        expect(employee.manager?).to be true
      end

      it 'returns true for hr role' do
        employee.role = 'hr'
        expect(employee.manager?).to be true
      end

      it 'returns true for admin role' do
        employee.role = 'admin'
        expect(employee.manager?).to be true
      end

      it 'returns false for employee role' do
        employee.role = 'employee'
        expect(employee.manager?).to be false
      end
    end

    describe '#hr_or_admin?' do
      it 'returns true for hr role' do
        employee.role = 'hr'
        expect(employee.hr_or_admin?).to be true
      end

      it 'returns true for admin role' do
        employee.role = 'admin'
        expect(employee.hr_or_admin?).to be true
      end

      it 'returns false for manager role' do
        employee.role = 'manager'
        expect(employee.hr_or_admin?).to be false
      end

      it 'returns false for employee role' do
        employee.role = 'employee'
        expect(employee.hr_or_admin?).to be false
      end
    end

    describe '#admin?' do
      it 'returns true for admin role' do
        employee.role = 'admin'
        expect(employee.admin?).to be true
      end

      it 'returns false for other roles' do
        %w[employee manager hr].each do |role|
          employee.role = role
          expect(employee.admin?).to be false
        end
      end
    end

    describe '#hr?' do
      it 'returns true for hr role' do
        employee.role = 'hr'
        expect(employee.hr?).to be true
      end

      it 'returns false for other roles' do
        %w[employee manager admin].each do |role|
          employee.role = role
          expect(employee.hr?).to be false
        end
      end
    end

    describe '#active?' do
      it 'returns true when settings active is true' do
        employee.settings = { active: true }
        expect(employee.active?).to be true
      end

      it 'returns false when settings active is false' do
        employee.settings = { active: false }
        expect(employee.active?).to be false
      end

      it 'returns true when settings is empty (default)' do
        employee.settings = {}
        expect(employee.active?).to be true
      end
    end

    describe '#tenure_in_months' do
      it 'calculates tenure correctly for recent hire' do
        employee.start_date = 3.months.ago.to_date
        expect(employee.tenure_in_months).to eq(3)
      end

      it 'calculates tenure correctly for long-term employee' do
        employee.start_date = 24.months.ago.to_date
        expect(employee.tenure_in_months).to eq(24)
      end

      it 'returns 0 for employees starting today' do
        employee.start_date = Date.current
        expect(employee.tenure_in_months).to eq(0)
      end
    end

    describe '#team_members' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let!(:team_member1) { create(:employee, organization: organization, manager: manager) }
      let!(:team_member2) { create(:employee, organization: organization, manager: manager) }
      let!(:other_employee) { create(:employee, organization: organization) }

      context 'when employee is a manager' do
        it 'returns all direct reports' do
          ActsAsTenant.with_tenant(organization) do
            team = manager.team_members
            expect(team).to include(team_member1, team_member2)
            expect(team).not_to include(other_employee)
            expect(team.count).to eq(2)
          end
        end
      end

      context 'when employee is not a manager' do
        it 'returns empty collection' do
          ActsAsTenant.with_tenant(organization) do
            regular_employee = create(:employee, role: 'employee', organization: organization)
            expect(regular_employee.team_members).to be_empty
          end
        end
      end
    end
  end

  describe 'multi-tenancy' do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let!(:employee1) { create(:employee, organization: org1) }
    let!(:employee2) { create(:employee, organization: org2) }

    it 'scopes queries to current organization' do
      ActsAsTenant.with_tenant(org1) do
        expect(Employee.all).to include(employee1)
        expect(Employee.all).not_to include(employee2)
      end
    end

    it 'can access employees from different organization when switching tenant' do
      ActsAsTenant.with_tenant(org2) do
        expect(Employee.all).to include(employee2)
        expect(Employee.all).not_to include(employee1)
      end
    end
  end

  describe 'contract types' do
    it 'accepts CDI contract type' do
      employee.contract_type = 'CDI'
      expect(employee).to be_valid
    end

    it 'accepts CDD contract type' do
      employee.contract_type = 'CDD'
      employee.end_date = 1.year.from_now.to_date
      expect(employee).to be_valid
    end

    it 'accepts Stage contract type' do
      employee.contract_type = 'Stage'
      expect(employee).to be_valid
    end

    it 'accepts Alternance contract type' do
      employee.contract_type = 'Alternance'
      expect(employee).to be_valid
    end

    it 'accepts Interim contract type' do
      employee.contract_type = 'Interim'
      expect(employee).to be_valid
    end
  end

  describe 'manager hierarchy' do
    let(:top_manager) { create(:employee, :manager, organization: organization) }
    let(:middle_manager) { create(:employee, :manager, organization: organization, manager: top_manager) }
    let(:team_member) { create(:employee, organization: organization, manager: middle_manager) }

    it 'allows creating manager hierarchy' do
      expect(team_member.manager).to eq(middle_manager)
      expect(middle_manager.manager).to eq(top_manager)
      expect(top_manager.manager).to be_nil
    end

    it 'tracks direct reports correctly' do
      ActsAsTenant.with_tenant(organization) do
        expect(top_manager.direct_reports).to include(middle_manager)
        expect(middle_manager.direct_reports).to include(team_member)
      end
    end
  end

  describe 'devise integration' do
    it 'has devise modules configured' do
      expect(Employee.devise_modules).to include(
        :database_authenticatable,
        :registerable,
        :recoverable,
        :rememberable,
        :validatable,
        :jwt_authenticatable
      )
    end
  end

  describe 'NIR/IBAN encryption' do
    let(:emp) { create(:employee, organization: organization, nir: '1850975123456', iban: 'FR7630006000011234567890189') }

    it 'stores NIR encrypted (ciphertext differs from plaintext)' do
      raw = emp.read_attribute_before_type_cast(:nir)
      expect(raw).not_to eq('1850975123456')
      expect(raw).to be_present
    end

    it 'stores IBAN encrypted (ciphertext differs from plaintext)' do
      raw = emp.read_attribute_before_type_cast(:iban)
      expect(raw).not_to eq('FR7630006000011234567890189')
      expect(raw).to be_present
    end

    it 'decrypts NIR transparently on read' do
      reloaded = Employee.find(emp.id)
      expect(reloaded.nir).to eq('1850975123456')
    end

    it 'decrypts IBAN transparently on read' do
      reloaded = Employee.find(emp.id)
      expect(reloaded.iban).to eq('FR7630006000011234567890189')
    end
  end

  describe 'NIR validations' do
    let(:emp) { build(:employee, organization: organization) }

    it 'accepts a valid NIR starting with 1' do
      emp.nir = '1850975123456'
      expect(emp).to be_valid
    end

    it 'accepts a valid NIR starting with 2' do
      emp.nir = '2850975123456'
      expect(emp).to be_valid
    end

    it 'rejects a NIR with wrong length' do
      emp.nir = '18509751234'
      expect(emp).not_to be_valid
      expect(emp.errors[:nir]).to be_present
    end

    it 'rejects a NIR starting with invalid digit' do
      emp.nir = '385097512345678'
      expect(emp).not_to be_valid
    end

    it 'allows blank NIR' do
      emp.nir = nil
      expect(emp).to be_valid
    end
  end

  describe 'NIR uniqueness within organization' do
    it 'rejects duplicate NIR within the same organization' do
      ActsAsTenant.with_tenant(organization) do
        create(:employee, organization: organization, nir: '1850975123456')
        dup = build(:employee, organization: organization, nir: '1850975123456')
        expect(dup).not_to be_valid
        expect(dup.errors[:nir]).to include('est déjà utilisé par un autre employé')
      end
    end

    it 'allows the same NIR in different organizations' do
      org2 = create(:organization)
      ActsAsTenant.with_tenant(organization) do
        create(:employee, organization: organization, nir: '1850975123456')
      end
      emp2 = ActsAsTenant.with_tenant(org2) do
        build(:employee, organization: org2, nir: '1850975123456')
      end
      expect(emp2).to be_valid
    end

    it 'allows updating an employee without changing NIR' do
      ActsAsTenant.with_tenant(organization) do
        emp = create(:employee, organization: organization, nir: '1850975123456')
        emp.first_name = 'Updated'
        expect(emp).to be_valid
      end
    end
  end
end
