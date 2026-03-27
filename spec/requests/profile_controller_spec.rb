# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ProfileController', type: :request do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  before do
    ActsAsTenant.current_tenant = org
    sign_in employee
  end

  after { ActsAsTenant.current_tenant = nil }

  describe 'PATCH /profile/dashboard_layout_mobile' do
    let(:valid_layout) do
      {
        dashboard_layout: {
          grid: [
            { id: 'leave_balances', x: 0, y: 0, w: 1, h: 3 },
            { id: 'quick_links',    x: 0, y: 3, w: 1, h: 4 }
          ],
          hidden: []
        }
      }
    end

    it 'returns 200 and saves the mobile layout' do
      patch dashboard_layout_mobile_profile_path, params: valid_layout, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      employee.reload
      expect(employee.settings['dashboard_layout_mobile']).to be_present
    end

    it 'persists grid items with correct structure' do
      patch dashboard_layout_mobile_profile_path, params: valid_layout, as: :json

      employee.reload
      grid = employee.settings['dashboard_layout_mobile']['grid']
      expect(grid.first['id']).to eq('leave_balances')
      expect(grid.first['w']).to eq(1)
    end

    it 'clamps w to 1 regardless of submitted value' do
      layout = {
        dashboard_layout: {
          grid: [{ id: 'leave_balances', x: 0, y: 0, w: 6, h: 3 }],
          hidden: []
        }
      }
      patch dashboard_layout_mobile_profile_path, params: layout, as: :json

      employee.reload
      w = employee.settings['dashboard_layout_mobile']['grid'].first['w']
      expect(w).to eq(1)
    end

    it 'strips cards not permitted for the employee role' do
      layout = {
        dashboard_layout: {
          grid: [
            { id: 'leave_balances', x: 0, y: 0, w: 1, h: 3 },
            { id: 'team_planning',  x: 0, y: 3, w: 1, h: 4 }  # manager-only
          ],
          hidden: []
        }
      }
      patch dashboard_layout_mobile_profile_path, params: layout, as: :json

      employee.reload
      ids = employee.settings['dashboard_layout_mobile']['grid'].map { |c| c['id'] }
      expect(ids).to include('leave_balances')
      expect(ids).not_to include('team_planning')
    end

    it 'does not affect the desktop layout' do
      employee.dashboard_layout = employee.dashboard_layout  # persist default
      employee.save!
      desktop_before = employee.dashboard_layout.deep_dup

      patch dashboard_layout_mobile_profile_path, params: valid_layout, as: :json

      employee.reload
      expect(employee.dashboard_layout['grid']).to eq(desktop_before['grid'])
    end

    it 'returns 401 when not authenticated' do
      sign_out employee
      patch dashboard_layout_mobile_profile_path, params: valid_layout, as: :json
      expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
    end
  end
end
