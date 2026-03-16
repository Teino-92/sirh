# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeSerializer do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org, role: 'employee') }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe '#as_json' do
    subject(:data) { described_class.new(employee).as_json }

    it 'includes core fields' do
      expect(data).to include(
        id:         employee.id,
        full_name:  employee.full_name,
        first_name: employee.first_name,
        last_name:  employee.last_name,
        email:      employee.email,
        role:       employee.role,
        department: employee.department,
        job_title:  employee.job_title,
        start_date: employee.start_date,
        cadre:      employee.cadre?
      )
    end

    it 'does not expose salary by default' do
      expect(data).not_to have_key(:gross_salary_cents)
      expect(data).not_to have_key(:variable_pay_cents)
      expect(data).not_to have_key(:employer_charges_rate)
    end

    context 'with include_salary: true and HR viewer' do
      subject(:data) do
        described_class.new(employee, include_salary: true, current_employee: hr).as_json
      end

      it 'exposes salary fields' do
        expect(data).to have_key(:gross_salary_cents)
        expect(data).to have_key(:variable_pay_cents)
        expect(data).to have_key(:employer_charges_rate)
      end
    end

    context 'with include_salary: true but non-HR viewer' do
      let(:manager) { create(:employee, organization: org, role: 'manager') }

      subject(:data) do
        described_class.new(employee, include_salary: true, current_employee: manager).as_json
      end

      it 'does not expose salary fields' do
        expect(data).not_to have_key(:gross_salary_cents)
      end
    end

    context 'with include_salary: true but no current_employee' do
      subject(:data) do
        described_class.new(employee, include_salary: true, current_employee: nil).as_json
      end

      it 'does not expose salary fields' do
        expect(data).not_to have_key(:gross_salary_cents)
      end
    end
  end
end
