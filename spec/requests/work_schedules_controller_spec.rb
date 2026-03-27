# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WorkSchedulesController', type: :request do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org, role: 'employee') }

  let(:default_pattern) do
    { 'monday' => '09:00-17:00', 'tuesday' => '09:00-17:00', 'wednesday' => '09:00-17:00',
      'thursday' => '09:00-17:00', 'friday' => '09:00-17:00', 'saturday' => 'off', 'sunday' => 'off' }
  end

  before do
    ActsAsTenant.current_tenant = org
    sign_in employee
  end

  after { ActsAsTenant.current_tenant = nil }

  describe 'GET /work_schedule/:id' do
    it 'responds 200 with no params (defaults to current month/week)' do
      get work_schedule_path(employee.id)
      expect(response).to have_http_status(:ok)
    end

    context 'mobile week param (?week=)' do
      it 'accepts a valid ISO date and sets the mobile week' do
        target_week = Date.new(2026, 4, 6)  # a Monday
        get work_schedule_path(employee.id, week: target_week.iso8601)
        expect(response).to have_http_status(:ok)
      end

      it 'defaults to current week when ?week= is absent' do
        get work_schedule_path(employee.id)
        expect(response).to have_http_status(:ok)
        # Response should include the current week's Monday date formatted
        expect(response.body).to include(Date.current.beginning_of_week(:monday).day.to_s)
      end

      it 'ignores a garbage ?week= value and falls back to current week' do
        get work_schedule_path(employee.id, week: 'not-a-date')
        expect(response).to have_http_status(:ok)
      end

      it 'shows weekly plan data when a WeeklySchedulePlan exists for the target week' do
        week_start = Date.current.beginning_of_week(:monday)
        ActsAsTenant.with_tenant(org) do
          WeeklySchedulePlan.create!(
            employee: employee,
            organization: org,
            week_start_date: week_start,
            schedule_pattern: default_pattern
          )
        end

        get work_schedule_path(employee.id, week: week_start.iso8601)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('09:00-17:00')
      end

      it 'shows non planifié when no plan exists for the target week' do
        future_week = (Date.current + 4.weeks).beginning_of_week(:monday)
        get work_schedule_path(employee.id, week: future_week.iso8601)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Non planifié')
      end
    end

    context 'month + week sync' do
      it 'accepts both ?date= and ?week= together' do
        month_date = Date.new(2026, 5, 1)
        week_date  = Date.new(2026, 5, 4).beginning_of_week(:monday)
        get work_schedule_path(employee.id, date: month_date.iso8601, week: week_date.iso8601)
        expect(response).to have_http_status(:ok)
      end

      it 'shows the correct month header when ?date= is set to another month' do
        get work_schedule_path(employee.id, date: Date.new(2026, 5, 1).iso8601,
                                             week: Date.new(2026, 5, 4).iso8601)
        expect(response.body).to include('mai')
      end

      it 'shows the correct week when navigating to a past week outside current month' do
        past_week = Date.new(2026, 2, 2).beginning_of_week(:monday)
        get work_schedule_path(employee.id, week: past_week.iso8601, date: past_week.iso8601)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(past_week.day.to_s)
      end
    end

    context 'when leave exists in the mobile week' do
      it 'shows the leave type badge in the mobile week view' do
        week_start = Date.current.beginning_of_week(:monday)
        ActsAsTenant.with_tenant(org) do
          create(:leave_balance, employee: employee, organization: org,
                 leave_type: 'CP', balance: 10, used_this_year: 0)
          create(:leave_request,
                 employee: employee, organization: org,
                 leave_type: 'CP', status: 'approved',
                 start_date: week_start + 1.day,
                 end_date: week_start + 1.day,
                 days_count: 1)
        end

        get work_schedule_path(employee.id, week: week_start.iso8601)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Congé')
      end
    end
  end
end
