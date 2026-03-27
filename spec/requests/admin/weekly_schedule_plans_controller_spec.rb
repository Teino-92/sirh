require 'rails_helper'

RSpec.describe 'Admin::WeeklySchedulePlans', type: :routing do
  describe 'GET /admin/weekly_schedule_plans' do
    it 'routes to the aggregate index action' do
      expect(get: '/admin/weekly_schedule_plans').to route_to(
        controller: 'admin/weekly_schedule_plans',
        action: 'index'
      )
    end
  end
end
