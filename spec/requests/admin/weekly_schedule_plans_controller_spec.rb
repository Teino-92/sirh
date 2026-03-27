require 'rails_helper'

RSpec.describe 'Admin::WeeklySchedulePlans', type: :request do
  include RSpec::Rails::Matchers::RoutingMatchers
  let(:org)      { create(:organization, plan: 'sirh') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe 'GET /admin/weekly_schedule_plans' do
    it 'routes to the aggregate index action' do
      expect(get: '/admin/weekly_schedule_plans').to route_to(
        controller: 'admin/weekly_schedule_plans',
        action: 'index'
      )
    end

    context 'when authenticated as admin' do
      before { sign_in admin }

      it 'returns 200' do
        get admin_weekly_schedule_plans_path
        expect(response).to have_http_status(:ok)
      end

      it 'defaults to current week when ?week param is absent' do
        get admin_weekly_schedule_plans_path
        expect(response.body).to include(Date.current.beginning_of_week(:monday).strftime('%d'))
      end

      it 'uses the given week when ?week param is valid' do
        target = Date.new(2026, 4, 6) # a Monday
        get admin_weekly_schedule_plans_path, params: { week: target.to_s }
        expect(response.body).to include('avril 2026')
      end
    end

    context 'when authenticated as manager' do
      before { sign_in manager }

      it 'redirects with unauthorized' do
        get admin_weekly_schedule_plans_path
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when authenticated as employee' do
      before { sign_in employee }

      it 'redirects with unauthorized' do
        get admin_weekly_schedule_plans_path
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        get admin_weekly_schedule_plans_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
