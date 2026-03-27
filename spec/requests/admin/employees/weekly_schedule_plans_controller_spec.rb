require 'rails_helper'

RSpec.describe 'Admin::Employees::WeeklySchedulePlans', type: :request do
  let(:org)      { create(:organization, plan: 'sirh') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:target)   { create(:employee, organization: org, role: 'employee') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe 'GET /admin/employees/:employee_id/weekly_schedule_plans' do
    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'returns 200' do
        get admin_employee_weekly_schedule_plans_path(target)
        expect(response).to have_http_status(:ok)
      end

      it 'defaults to current month when ?date param is absent' do
        get admin_employee_weekly_schedule_plans_path(target)
        expect(response.body).to include(I18n.l(Date.current, format: '%B %Y').capitalize)
      end

      it 'uses the given month when ?date param is valid' do
        get admin_employee_weekly_schedule_plans_path(target, date: '2026-05-01')
        expect(response.body).to include('Mai 2026')
      end

      it 'shows only plans belonging to the requested employee' do
        other = create(:employee, organization: org, role: 'employee')
        WeeklySchedulePlan.create!(
          employee: target,
          week_start_date: Date.current.beginning_of_week(:monday),
          schedule_pattern: { 'monday' => '09:00-17:00' }
        )
        WeeklySchedulePlan.create!(
          employee: other,
          week_start_date: Date.current.beginning_of_week(:monday),
          schedule_pattern: { 'monday' => '08:00-16:00' }
        )
        get admin_employee_weekly_schedule_plans_path(target)
        expect(response.body).to include(target.full_name)
        expect(response.body).not_to include('08:00-16:00')
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'redirects with unauthorized' do
        get admin_employee_weekly_schedule_plans_path(target)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
