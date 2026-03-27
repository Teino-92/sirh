# Admin Org-Wide Schedule View — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give admin-role employees read-only access to all weekly schedule plans in the organisation — both an aggregate week view and a per-employee calendar view — accessible from the admin employee list.

**Architecture:** Two new read-only controllers under `Admin::` namespace. No Pundit policy changes needed (scope already returns `scope.all` for `hr_or_admin?`). Two new view directories. Two new entry points in existing admin employee views.

**Tech Stack:** Rails 7.1, Pundit, acts_as_tenant, Tailwind CSS, Turbo

---

## File Map

| Action | Path |
|--------|------|
| Create | `app/controllers/admin/weekly_schedule_plans_controller.rb` |
| Create | `app/controllers/admin/employees/weekly_schedule_plans_controller.rb` |
| Create | `app/views/admin/weekly_schedule_plans/index.html.erb` |
| Create | `app/views/admin/employees/weekly_schedule_plans/index.html.erb` |
| Modify | `config/routes.rb` |
| Modify | `app/views/admin/employees/index.html.erb` |
| Modify | `app/views/admin/employees/_employee.html.erb` |
| Create | `spec/requests/admin/weekly_schedule_plans_controller_spec.rb` |
| Create | `spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb` |

---

## Task 1: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/admin/weekly_schedule_plans_controller_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::WeeklySchedulePlans', type: :request do
  let(:org)   { create(:organization, plan: 'sirh') }
  let(:admin) { create(:employee, organization: org, role: 'admin') }

  before do
    ActsAsTenant.current_tenant = org
    sign_in admin
  end
  after { ActsAsTenant.current_tenant = nil }

  describe 'GET /admin/weekly_schedule_plans' do
    it 'routes to the aggregate index action' do
      expect(get: '/admin/weekly_schedule_plans').to route_to(
        controller: 'admin/weekly_schedule_plans',
        action: 'index'
      )
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/requests/admin/weekly_schedule_plans_controller_spec.rb -e "routes to the aggregate index action" --format documentation
```

Expected: FAIL — "No route matches"

- [ ] **Step 3: Add routes**

In `config/routes.rb`, inside the `namespace :admin do` block (after `resources :employees`), add:

```ruby
# Aggregate org-wide view: /admin/weekly_schedule_plans?week=YYYY-MM-DD
resources :weekly_schedule_plans, only: [:index]

# Per-employee calendar: /admin/employees/:employee_id/weekly_schedule_plans?date=YYYY-MM-DD
resources :employees do
  resources :weekly_schedule_plans, only: [:index], module: :employees
end
```

The existing `resources :employees` (standalone) and this nested `resources :employees` block coexist — Rails merges them, the nested one only adds the sub-resource routes.

- [ ] **Step 4: Run test to verify it passes**

```bash
bundle exec rspec spec/requests/admin/weekly_schedule_plans_controller_spec.rb -e "routes to the aggregate index action" --format documentation
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb spec/requests/admin/weekly_schedule_plans_controller_spec.rb
git commit -m "feat(routes): add admin weekly_schedule_plans aggregate and per-employee routes"
```

---

## Task 2: Aggregate controller

**Files:**
- Create: `app/controllers/admin/weekly_schedule_plans_controller.rb`
- Modify: `spec/requests/admin/weekly_schedule_plans_controller_spec.rb`

- [ ] **Step 1: Write the failing tests**

Replace the routing test from Task 1 with the full spec (keep the routing test, append these):

```ruby
# spec/requests/admin/weekly_schedule_plans_controller_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::WeeklySchedulePlans', type: :request do
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/requests/admin/weekly_schedule_plans_controller_spec.rb --format documentation
```

Expected: multiple FAILs — "uninitialized constant Admin::WeeklySchedulePlansController"

- [ ] **Step 3: Create the controller**

```ruby
# app/controllers/admin/weekly_schedule_plans_controller.rb
# frozen_string_literal: true

module Admin
  class WeeklySchedulePlansController < BaseController
    def index
      @week_start = parse_week_param || Date.current.beginning_of_week(:monday)
      @week_end   = @week_start + 6.days
      @prev_week  = @week_start - 1.week
      @next_week  = @week_start + 1.week

      @employees      = policy_scope(Employee).order(:last_name, :first_name)
      plans           = policy_scope(WeeklySchedulePlan)
                          .where(week_start_date: @week_start)
                          .includes(:employee)
      @plans_by_employee = plans.index_by(&:employee_id)
    end

    private

    def parse_week_param
      params[:week]&.to_date&.beginning_of_week(:monday)
    rescue ArgumentError
      nil
    end
  end
end
```

- [ ] **Step 4: Create a minimal view so the controller renders**

```erb
<%# app/views/admin/weekly_schedule_plans/index.html.erb %>
<div>Plannings</div>
```

(This placeholder will be replaced in Task 4.)

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/requests/admin/weekly_schedule_plans_controller_spec.rb --format documentation
```

Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/weekly_schedule_plans_controller.rb \
        app/views/admin/weekly_schedule_plans/index.html.erb \
        spec/requests/admin/weekly_schedule_plans_controller_spec.rb
git commit -m "feat(admin): aggregate weekly schedule plans controller (read-only)"
```

---

## Task 3: Per-employee controller

**Files:**
- Create: `app/controllers/admin/employees/weekly_schedule_plans_controller.rb`
- Create: `spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb`

- [ ] **Step 1: Write the failing tests**

```ruby
# spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb
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
        expect(response.body).to include('mai 2026')
      end

      it 'shows only plans belonging to the requested employee' do
        other = create(:employee, organization: org, role: 'employee')
        plan_target = WeeklySchedulePlan.create!(
          employee: target,
          week_start_date: Date.current.beginning_of_week(:monday),
          schedule_pattern: { 'monday' => '09:00-17:00' }
        )
        plan_other = WeeklySchedulePlan.create!(
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb --format documentation
```

Expected: FAILs — "uninitialized constant Admin::Employees"

- [ ] **Step 3: Create the controller**

```ruby
# app/controllers/admin/employees/weekly_schedule_plans_controller.rb
# frozen_string_literal: true

module Admin
  module Employees
    class WeeklySchedulePlansController < Admin::BaseController
      before_action :set_employee

      def index
        @current_date   = parse_date_param || Date.current
        @start_date     = @current_date.beginning_of_month.beginning_of_week(:monday)
        @end_date       = @current_date.end_of_month.end_of_week(:sunday)

        @weekly_plans   = policy_scope(WeeklySchedulePlan)
                            .where(employee: @employee)
                            .where(week_start_date: @start_date..@end_date)
                            .index_by(&:week_start_date)

        @calendar_weeks = (@start_date..@end_date).step(7).map { |d| d }
      end

      private

      def set_employee
        @employee = Employee.find(params[:employee_id])
        authorize @employee, :show?
      end

      def parse_date_param
        params[:date]&.to_date
      rescue ArgumentError
        nil
      end
    end
  end
end
```

- [ ] **Step 4: Create a minimal placeholder view**

```erb
<%# app/views/admin/employees/weekly_schedule_plans/index.html.erb %>
<div><%= @employee.full_name %></div>
```

(Will be replaced in Task 5.)

- [ ] **Step 5: Run tests to verify they pass**

```bash
bundle exec rspec spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb --format documentation
```

Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/admin/employees/weekly_schedule_plans_controller.rb \
        app/views/admin/employees/weekly_schedule_plans/index.html.erb \
        spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb
git commit -m "feat(admin): per-employee weekly schedule plans controller (read-only)"
```

---

## Task 4: Aggregate view

**Files:**
- Modify: `app/views/admin/weekly_schedule_plans/index.html.erb`

- [ ] **Step 1: Replace the placeholder with the full view**

```erb
<%# app/views/admin/weekly_schedule_plans/index.html.erb %>
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
  <!-- Header -->
  <div class="mb-6 flex items-center justify-between">
    <div>
      <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">Plannings de l'organisation</h1>
      <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
        Semaine du <%= l(@week_start, format: :short) %> au <%= l(@week_end, format: :short) %>
      </p>
    </div>
    <%= link_to admin_employees_path,
        class: "text-sm text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300" do %>
      ← Retour aux employés
    <% end %>
  </div>

  <!-- Week Navigation -->
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow mb-6 p-4">
    <div class="flex items-center justify-between">
      <%= link_to admin_weekly_schedule_plans_path(week: @prev_week),
          class: "inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600" do %>
        <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
        Semaine précédente
      <% end %>

      <h2 class="text-lg font-bold text-gray-900 dark:text-gray-100">
        <%= l(@week_start, format: :short) %> – <%= l(@week_end, format: :short) %>
      </h2>

      <%= link_to admin_weekly_schedule_plans_path(week: @next_week),
          class: "inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600" do %>
        Semaine suivante
        <svg class="w-5 h-5 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      <% end %>
    </div>
  </div>

  <!-- Table -->
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-900">
          <tr>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider w-48">
              Employé
            </th>
            <% %w[monday tuesday wednesday thursday friday saturday sunday].each do |day| %>
              <% day_date = @week_start + %w[monday tuesday wednesday thursday friday saturday sunday].index(day).days %>
              <th scope="col" class="px-3 py-3 text-center text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                <div><%= l(day_date, format: '%a') %></div>
                <div class="font-normal normal-case text-gray-400 dark:text-gray-500"><%= l(day_date, format: '%d/%m') %></div>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <% @employees.each do |emp| %>
            <% plan = @plans_by_employee[emp.id] %>
            <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
              <td class="px-4 py-3 whitespace-nowrap">
                <%= link_to admin_employee_weekly_schedule_plans_path(emp),
                    class: "flex items-center gap-2 group" do %>
                  <div class="h-8 w-8 rounded-full bg-indigo-100 dark:bg-indigo-800 flex-shrink-0 flex items-center justify-center">
                    <span class="text-indigo-700 dark:text-indigo-300 text-xs font-semibold">
                      <%= emp.first_name[0] %><%= emp.last_name[0] %>
                    </span>
                  </div>
                  <span class="text-sm font-medium text-gray-900 dark:text-gray-100 group-hover:text-indigo-600 dark:group-hover:text-indigo-400">
                    <%= emp.full_name %>
                  </span>
                <% end %>
              </td>
              <% %w[monday tuesday wednesday thursday friday saturday sunday].each do |day| %>
                <td class="px-3 py-3 text-center">
                  <% if plan %>
                    <% hours = plan.schedule_pattern[day] %>
                    <% if hours.present? && hours != 'off' %>
                      <span class="text-xs font-medium text-gray-900 dark:text-gray-100"><%= hours %></span>
                    <% else %>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400">Repos</span>
                    <% end %>
                  <% else %>
                    <span class="text-gray-300 dark:text-gray-600">—</span>
                  <% end %>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <% if @employees.empty? %>
      <div class="py-12 text-center text-sm text-gray-400 dark:text-gray-500">
        Aucun employé dans l'organisation.
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2: Verify in browser**

Navigate to `http://localhost:3000/admin/weekly_schedule_plans` as an admin.

Expected:
- Table with one row per employee
- Navigation prev/next semaine fonctionne
- Clic sur un nom navigue vers la vue calendrier (Task 5, peut afficher le placeholder pour l'instant)

- [ ] **Step 3: Commit**

```bash
git add app/views/admin/weekly_schedule_plans/index.html.erb
git commit -m "feat(admin): aggregate weekly schedule plans view"
```

---

## Task 5: Per-employee calendar view

**Files:**
- Modify: `app/views/admin/employees/weekly_schedule_plans/index.html.erb`

- [ ] **Step 1: Replace the placeholder with the full view**

```erb
<%# app/views/admin/employees/weekly_schedule_plans/index.html.erb %>
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
  <!-- Header -->
  <div class="mb-6">
    <div class="flex items-center text-gray-600 dark:text-gray-400 mb-4">
      <%= link_to admin_employees_path, class: "text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300" do %>
        ← Retour aux employés
      <% end %>
    </div>

    <div class="flex items-center">
      <div class="h-12 w-12 rounded-full bg-indigo-100 dark:bg-indigo-800 flex items-center justify-center mr-4">
        <span class="text-indigo-700 dark:text-indigo-300 font-semibold text-lg">
          <%= @employee.first_name[0] %><%= @employee.last_name[0] %>
        </span>
      </div>
      <div>
        <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100"><%= @employee.full_name %></h1>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          <%= @employee.contract_type %>
          <% if @employee.work_schedule %>
            • <%= @employee.work_schedule.weekly_hours %>h/semaine
          <% end %>
        </p>
      </div>
    </div>
  </div>

  <!-- Month Navigation -->
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow mb-6 p-4">
    <div class="flex items-center justify-between">
      <%= link_to admin_employee_weekly_schedule_plans_path(@employee, date: @current_date - 1.month),
          class: "inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600" do %>
        <svg class="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
        </svg>
        Mois précédent
      <% end %>

      <h2 class="text-xl font-bold text-gray-900 dark:text-gray-100">
        <%= l(@current_date, format: '%B %Y').capitalize %>
      </h2>

      <%= link_to admin_employee_weekly_schedule_plans_path(@employee, date: @current_date + 1.month),
          class: "inline-flex items-center px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600" do %>
        Mois suivant
        <svg class="w-5 h-5 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      <% end %>
    </div>
  </div>

  <!-- Read-only info banner -->
  <div class="bg-amber-50 dark:bg-amber-900/30 border border-amber-200 dark:border-amber-700 rounded-lg p-4 mb-6">
    <div class="flex items-center gap-2 text-sm text-amber-700 dark:text-amber-300">
      <svg class="h-4 w-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
      </svg>
      Vue consultation uniquement — les modifications se font depuis l'interface du manager.
    </div>
  </div>

  <!-- Weekly Calendar (read-only) -->
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
    <div class="divide-y divide-gray-200 dark:divide-gray-700">
      <% @calendar_weeks.each do |week_start| %>
        <%
          week_end = week_start + 6.days
          plan = @weekly_plans[week_start]
          is_current_week = week_start == Date.current.beginning_of_week(:monday)
          is_past = week_start < Date.current.beginning_of_week(:monday)
          in_current_month = week_start.month == @current_date.month || week_end.month == @current_date.month
        %>
        <div class="p-4 sm:p-6 <%= 'bg-gray-50 dark:bg-gray-900' unless in_current_month %> <%= 'bg-green-50 dark:bg-green-900/30' if is_current_week %>">
          <!-- Week Header -->
          <div class="flex items-center gap-3 mb-4">
            <h3 class="text-base sm:text-lg font-semibold text-gray-900 dark:text-gray-100">
              Semaine du <%= l(week_start, format: :short) %>
            </h3>
            <% if is_current_week %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-600 text-white">Cette semaine</span>
            <% elsif is_past %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-400 text-white">Passée</span>
            <% end %>
          </div>

          <!-- Week Content -->
          <% if plan %>
            <div class="grid grid-cols-2 sm:grid-cols-7 gap-2">
              <% %w[monday tuesday wednesday thursday friday saturday sunday].each do |day| %>
                <% hours = plan.schedule_pattern[day] %>
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-3 text-center">
                  <p class="text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
                    <%= l(week_start + %w[monday tuesday wednesday thursday friday saturday sunday].index(day).days, format: '%a') %>
                  </p>
                  <% if hours.present? && hours != 'off' %>
                    <p class="text-sm font-semibold text-gray-900 dark:text-gray-100"><%= hours %></p>
                  <% else %>
                    <p class="text-sm text-gray-400 dark:text-gray-500">Repos</p>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="mt-3 text-sm text-gray-600 dark:text-gray-400">
              <span class="font-semibold"><%= plan.total_weekly_hours.round(1) %>h</span> de travail
              <% if plan.notes.present? %>
                <span class="ml-3 italic">Note : <%= plan.notes %></span>
              <% end %>
            </div>
          <% else %>
            <div class="bg-gray-100 dark:bg-gray-800 border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg p-6 text-center">
              <p class="text-gray-500 dark:text-gray-400 text-sm">Semaine non planifiée</p>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Verify in browser**

Navigate to `http://localhost:3000/admin/weekly_schedule_plans`, clic sur un nom d'employé.

Expected:
- Header avec nom + initiales
- Calendrier mensuel identique à la vue manager
- Aucun bouton Modifier / Planifier / Supprimer / Copier
- Bannière "Vue consultation uniquement"
- Navigation mois prev/next fonctionne

- [ ] **Step 3: Run all request specs**

```bash
bundle exec rspec spec/requests/admin/ --format documentation
```

Expected: all PASS

- [ ] **Step 4: Commit**

```bash
git add app/views/admin/employees/weekly_schedule_plans/index.html.erb
git commit -m "feat(admin): per-employee weekly schedule plans calendar view (read-only)"
```

---

## Task 6: Entry points in admin employee views

**Files:**
- Modify: `app/views/admin/employees/index.html.erb`
- Modify: `app/views/admin/employees/_employee.html.erb`

- [ ] **Step 1: Add "Tous les plannings" button to `index.html.erb`**

In `app/views/admin/employees/index.html.erb`, locate the header action div (the `div` containing "Importer CSV" and "Nouvel Employé" buttons — around line 35). Add this **before** the "Importer CSV" link:

```erb
<% if sirh_plan? %>
  <%= link_to admin_weekly_schedule_plans_path,
      class: "inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
    <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
    </svg>
    Tous les plannings
  <% end %>
<% end %>
```

- [ ] **Step 2: Add per-employee calendar link to `_employee.html.erb`**

In `app/views/admin/employees/_employee.html.erb`, in the actions `div` (around line 47), add this **before** the delete button:

```erb
<% if sirh_plan? %>
  <%= link_to admin_employee_weekly_schedule_plans_path(employee),
      class: "p-2 text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors",
      "aria-label": "Plannings de #{employee.full_name}",
      title: "Plannings" do %>
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
    </svg>
  <% end %>
<% end %>
```

- [ ] **Step 3: Verify in browser**

Navigate to `http://localhost:3000/admin/employees` as admin with `sirh` plan.

Expected:
- Bouton "Tous les plannings" visible dans le header
- Icône calendrier visible sur chaque ligne employé
- Les deux liens naviguent vers les bonnes vues

- [ ] **Step 4: Run all specs**

```bash
bundle exec rspec spec/requests/admin/ --format documentation
```

Expected: all PASS

- [ ] **Step 5: Commit and push**

```bash
git add app/views/admin/employees/index.html.erb \
        app/views/admin/employees/_employee.html.erb
git commit -m "feat(admin): add schedule plan entry points to employee list"
git push origin master
```

---

## Self-Review

**Spec coverage:**
- ✅ Admin-only access (Tasks 2, 3 — authorization via `Admin::BaseController#authorize_admin!`)
- ✅ Aggregate view with week navigation (Task 2 controller + Task 4 view)
- ✅ Per-employee calendar view (Task 3 controller + Task 5 view)
- ✅ Entry points from employee list (Task 6)
- ✅ Read-only — no create/edit/destroy links anywhere
- ✅ `sirh_plan?` guard on entry points
- ✅ Multi-tenancy: `policy_scope` + `acts_as_tenant` active
- ✅ Tests: access control, param handling, data isolation

**Placeholders:** none.

**Type consistency:** `@plans_by_employee` uses `employee_id` as key (integer) throughout; `@weekly_plans` uses `week_start_date` (Date) throughout — consistent across controller and view.
