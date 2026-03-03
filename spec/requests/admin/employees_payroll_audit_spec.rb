# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Employees payroll audit trail', type: :request do
  let(:org)  { create(:organization) }
  let(:hr)   { create(:employee, organization: org, role: 'hr') }
  let(:emp_with_nir)  { create(:employee, organization: org, role: 'employee', nir: '1850975123456') }
  let(:emp_no_nir)    { create(:employee, organization: org, role: 'employee') }

  before do
    ActsAsTenant.current_tenant = org
    sign_in hr
  end

  after { ActsAsTenant.current_tenant = nil }

  describe 'GET /admin/employees/:id (show)' do
    context 'when employee has sensitive payroll data (NIR stored)' do
      it 'creates a payroll_data_viewed PaperTrail version' do
        expect {
          get admin_employee_path(emp_with_nir)
        }.to change(PaperTrail::Version, :count).by(1)

        v = PaperTrail::Version.last
        expect(v.event).to eq('payroll_data_viewed')
        expect(v.item_type).to eq('Employee')
        expect(v.item_id).to eq(emp_with_nir.id)
        expect(v.whodunnit).to eq(hr.id.to_s)
        expect(v.organization_id).to eq(org.id)
      end
    end

    context 'when employee has no sensitive payroll data' do
      it 'does not create a payroll_data_viewed version' do
        expect {
          get admin_employee_path(emp_no_nir)
        }.not_to change(PaperTrail::Version, :count)
      end
    end
  end

  describe 'GET /admin/employees/:id/edit' do
    context 'when employee has sensitive payroll data' do
      it 'creates a payroll_data_viewed PaperTrail version' do
        expect {
          get edit_admin_employee_path(emp_with_nir)
        }.to change(PaperTrail::Version, :count).by(1)

        v = PaperTrail::Version.last
        expect(v.event).to eq('payroll_data_viewed')
      end
    end

    context 'when employee has no sensitive payroll data' do
      it 'does not create an audit version' do
        expect {
          get edit_admin_employee_path(emp_no_nir)
        }.not_to change(PaperTrail::Version, :count)
      end
    end
  end

  describe 'cross-tenant isolation' do
    it 'cannot access an employee from another organization' do
      org_b = create(:organization)
      emp_b = ActsAsTenant.without_tenant { create(:employee, organization: org_b, role: 'employee') }

      get admin_employee_path(emp_b)
      expect(response).to have_http_status(:not_found).or be_redirect
    end
  end
end
