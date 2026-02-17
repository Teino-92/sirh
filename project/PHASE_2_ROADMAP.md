# PHASE 2 ROADMAP — PERFORMANCE LAYER

**Date**: 2026-02-16
**Target Agent**: @developer
**Source**: PERFORMANCE_LAYER_ARCHITECTURE.md (approved by @architect)
**Priority**: Execute sequentially, Sprint by Sprint

---

## 📋 HOW TO USE THIS ROADMAP

This is your **step-by-step implementation guide** for the Performance Layer (Objectives, 1:1s, Evaluations, Training).

**IMPORTANT RULES**:
1. **Read PERFORMANCE_LAYER_ARCHITECTURE.md first** - Contains full context
2. **One sprint at a time** - Complete ALL tasks before moving to next
3. **Tests MUST pass** - 80% coverage target for new code
4. **@qa validation required** - Each sprint ends with @qa → @architect validation
5. **Follow the schema exactly** - No improvisation on database design
6. **Commit after each task** - Small, focused commits

---

## 🎯 SPRINT OVERVIEW

| Sprint | Focus | Effort | Dependencies | Status |
|--------|-------|--------|--------------|--------|
| **2.1** | Objectives + 1:1 Meetings | 8-10h | None | ✅ COMPLETE (architect validated 2026-02-17) |
| **2.2** | Evaluations System | 6-8h | Sprint 2.1 | ✅ COMPLETE (architect validated 2026-02-17) |
| **2.3** | Training Tracker | 6-8h | Sprint 2.2 | ✅ COMPLETE (architect validated 2026-02-17) |
| **2.4** | Dashboards + Polish | 4-6h | Sprint 2.3 | 🔄 READY |

**Total Estimated Effort**: 24-32 hours (3-4 working days)

---

# SPRINT 2.1 — OBJECTIVES + 1:1 MEETINGS

**Objective**: Implement goal tracking and structured 1:1 meetings for managers

**Effort**: 8-10 hours

**Complexity**: MEDIUM (new domains, relationships, authorization)

**Architecture Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md (lines 51-450)

---

## 📝 Context

This sprint implements 2 core performance management features:
1. **Objectives**: Managers set goals for employees, track progress, identify overdue items
2. **One-on-Ones**: Managers schedule recurring meetings, create action items, track follow-ups

**Key Architectural Decisions**:
- Objectives use **polymorphic owner** (Employee now, Team later)
- 1:1s can **optionally link** to objectives (loose coupling)
- Action items can be assigned to manager OR employee
- All models enforce **multi-tenancy** via `acts_as_tenant`

---

## 🎯 Acceptance Criteria

### Database
- [x] 4 migrations created and run successfully
- [x] All foreign keys enforced
- [x] Indexes created (composite + partial)
- [x] Multi-tenancy validation in place

### Models
- [x] Objective model with validations + scopes
- [x] OneOnOne model with validations + scopes
- [x] ActionItem model with validations + scopes
- [x] Join table: OneOnOneObjective
- [x] All models have 80%+ test coverage

### Authorization
- [x] ObjectivePolicy (manager can CRUD team objectives)
- [x] OneOnOnePolicy (manager can schedule/complete)
- [x] ActionItemPolicy (responsible can complete)
- [x] All policies tested

### Controllers
- [x] Manager::ObjectivesController (CRUD)
- [x] Manager::OneOnOnesController (schedule, complete)
- [x] ObjectivesController (employee read-only)
- [x] OneOnOnesController (employee read-only)
- [x] All actions authorized via Pundit

### Views (Basic)
- [x] Manager objectives index (list with filters)
- [x] Manager 1:1s index (upcoming + past)
- [x] Employee objectives view
- [x] Mobile-first Tailwind styling

### Service Objects
- [x] Objectives::Services::ObjectiveTracker
- [x] OneOnOnes::Services::ActionItemTracker
- [x] Service tests at 80%+ coverage

### Tests
- [x] `bundle exec rspec` passes (100%)
- [x] New code coverage ≥80%
- [x] Multi-tenancy isolation tests
- [x] Authorization tests

---

## 🛠️ IMPLEMENTATION STEPS

### TASK 2.1.1 — Create Domain Structure

**Duration**: 15 minutes

**Commands**:
```bash
# Create domain directories
mkdir -p app/domains/objectives/{models,services,queries}
mkdir -p app/domains/one_on_ones/{models,services,queries}

# Create policy files
touch app/policies/objective_policy.rb
touch app/policies/one_on_one_policy.rb
touch app/policies/action_item_policy.rb

# Create controller directories
mkdir -p app/controllers/manager
touch app/controllers/manager/objectives_controller.rb
touch app/controllers/manager/one_on_ones_controller.rb
touch app/controllers/objectives_controller.rb
touch app/controllers/one_on_ones_controller.rb
```

**Verification**:
```bash
tree app/domains/objectives/
tree app/domains/one_on_ones/
ls app/policies/*objective*.rb
ls app/policies/*one_on_one*.rb
```

**Commit**:
```bash
git add app/domains/objectives app/domains/one_on_ones app/policies app/controllers/manager
git commit -m "chore(structure): create domains for objectives and one-on-ones

Sprint 2.1 - Performance Layer
- Created objectives domain structure (models, services, queries)
- Created one_on_ones domain structure
- Created policy placeholders
- Created controller placeholders

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.2 — Create Objectives Migration

**Duration**: 30 minutes

**Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md lines 135-183

**Command**:
```bash
rails g migration CreateObjectives
```

**File**: `db/migrate/XXXXXX_create_objectives.rb`

**Implementation** (COPY EXACTLY from architecture doc lines 170-183):
```ruby
class CreateObjectives < ActiveRecord::Migration[7.1]
  def change
    create_table :objectives do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.references :manager, null: false, foreign_key: { to_table: :employees }, index: true
      t.references :created_by, null: false, foreign_key: { to_table: :employees }

      # Polymorphic owner (Employee or Team)
      t.references :owner, polymorphic: true, null: false, index: true

      t.string :title, null: false, limit: 255
      t.text :description
      t.string :status, null: false, default: 'draft', index: true
      t.string :priority, default: 'medium'
      t.date :deadline, null: false, index: true
      t.date :completed_at

      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    # Composite indexes for common queries
    add_index :objectives, [:organization_id, :status, :deadline], name: 'idx_objectives_org_status_deadline'
    add_index :objectives, [:manager_id, :status], name: 'idx_objectives_manager_status'
    add_index :objectives, [:owner_type, :owner_id, :status], name: 'idx_objectives_owner_status'

    # Partial index for overdue objectives (hot query)
    add_index :objectives, [:manager_id, :deadline],
              where: "status IN ('draft', 'in_progress', 'blocked') AND deadline < CURRENT_DATE",
              name: 'idx_objectives_overdue'
  end
end
```

**Run Migration**:
```bash
rails db:migrate
```

**Verify**:
```bash
psql -d easy_rh_development -c "\d objectives"
# Should show table with all columns and indexes
```

**Commit**:
```bash
git add db/migrate/*_create_objectives.rb db/schema.rb
git commit -m "feat(objectives): add objectives table with indexes

Sprint 2.1 - Objectives Module
- Created objectives table with polymorphic owner
- Added composite indexes for common queries
- Added partial index for overdue objectives
- Multi-tenancy via organization_id
- Metadata JSONB for future extensibility

Migration time: ~50ms

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.3 — Create Objective Model

**Duration**: 45 minutes

**Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md lines 95-134

**File**: `app/domains/objectives/models/objective.rb`

**Implementation** (COPY from architecture doc, lines 95-134):
```ruby
class Objective < ApplicationRecord
  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  # Core relationships
  belongs_to :owner, polymorphic: true
  belongs_to :manager, class_name: 'Employee'
  belongs_to :created_by, class_name: 'Employee'

  # Optional relationships (loose coupling)
  has_many :evaluation_objectives, dependent: :nullify
  has_many :evaluations, through: :evaluation_objectives
  has_many :one_on_one_objectives, dependent: :nullify
  has_many :one_on_ones, through: :one_on_one_objectives

  # Enums
  enum status: {
    draft: 'draft',
    in_progress: 'in_progress',
    completed: 'completed',
    blocked: 'blocked',
    cancelled: 'cancelled'
  }

  enum priority: {
    low: 'low',
    medium: 'medium',
    high: 'high',
    critical: 'critical'
  }

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :status, presence: true
  validates :owner_type, inclusion: { in: %w[Employee] }
  validates :deadline, presence: true
  validate :deadline_in_future, on: :create
  validate :manager_in_same_organization
  validate :owner_in_same_organization

  # Scopes
  scope :active, -> { where(status: [:draft, :in_progress, :blocked]) }
  scope :overdue, -> { active.where('deadline < ?', Date.current) }
  scope :upcoming, -> { active.where('deadline BETWEEN ? AND ?', Date.current, 30.days.from_now) }
  scope :for_manager, ->(manager) { where(manager: manager) }
  scope :for_owner, ->(owner) { where(owner: owner) }

  # Instance methods
  def overdue?
    active? && deadline < Date.current
  end

  def active?
    draft? || in_progress? || blocked?
  end

  def complete!
    update!(status: :completed, completed_at: Time.current)
  end

  private

  def deadline_in_future
    return unless deadline.present? && deadline < Date.current
    errors.add(:deadline, 'must be in the future')
  end

  def manager_in_same_organization
    return unless manager.present? && organization.present?
    return if manager.organization_id == organization_id

    errors.add(:manager, 'must belong to the same organization')
  end

  def owner_in_same_organization
    return unless owner.present? && owner.respond_to?(:organization_id)
    return if owner.organization_id == organization_id

    errors.add(:owner, 'must belong to the same organization')
  end
end
```

**Update Employee Model** (add reverse association):

**File**: `app/domains/employees/models/employee.rb`

Add:
```ruby
# Performance Layer relationships
has_many :owned_objectives, class_name: 'Objective', as: :owner, dependent: :destroy
has_many :managed_objectives, class_name: 'Objective', foreign_key: :manager_id, dependent: :nullify
```

**Commit**:
```bash
git add app/domains/objectives/models/objective.rb app/domains/employees/models/employee.rb
git commit -m "feat(objectives): add Objective model with validations

Sprint 2.1 - Objectives Module
- Added Objective model with polymorphic owner
- Validations: title, deadline, same-org checks
- Enums: status (draft/in_progress/completed/blocked/cancelled)
- Enums: priority (low/medium/high/critical)
- Scopes: active, overdue, upcoming, for_manager, for_owner
- Methods: complete!, overdue?, active?
- Multi-tenancy enforcement via acts_as_tenant

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.4 — Create One-on-Ones Migrations

**Duration**: 45 minutes

**Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md lines 318-380

**Commands**:
```bash
rails g migration CreateOneOnOnes
rails g migration CreateActionItems
rails g migration CreateOneOnOneObjectives
```

**Implementation** (COPY from architecture doc):

See architecture doc for exact migration code.

**Run Migrations**:
```bash
rails db:migrate
```

**Verify**:
```bash
psql -d easy_rh_development -c "\d one_on_ones"
psql -d easy_rh_development -c "\d action_items"
psql -d easy_rh_development -c "\d one_on_one_objectives"
```

**Commit**:
```bash
git add db/migrate/*one_on_one* db/migrate/*action_item* db/schema.rb
git commit -m "feat(one-on-ones): add one_on_ones and action_items tables

Sprint 2.1 - One-on-Ones Module
- Created one_on_ones table (manager + employee + scheduled_at)
- Created action_items table (linked to 1:1, responsible employee)
- Created one_on_one_objectives join table (optional link)
- Added composite indexes for manager/employee queries
- Added partial index for upcoming 1:1s
- Added partial index for overdue action items

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.5 — Create One-on-One Models

**Duration**: 1 hour

**Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md lines 186-316

**Files**:
- `app/domains/one_on_ones/models/one_on_one.rb`
- `app/domains/one_on_ones/models/action_item.rb`

**Implementation**: COPY from architecture doc (lines 186-316)

**Update Employee Model**:
```ruby
# One-on-Ones relationships
has_many :managed_one_on_ones, class_name: 'OneOnOne', foreign_key: :manager_id, dependent: :nullify
has_many :employee_one_on_ones, class_name: 'OneOnOne', foreign_key: :employee_id, dependent: :destroy
has_many :action_items, foreign_key: :responsible_id, dependent: :nullify
```

**Commit**:
```bash
git add app/domains/one_on_ones/models/*.rb app/domains/employees/models/employee.rb
git commit -m "feat(one-on-ones): add OneOnOne and ActionItem models

Sprint 2.1 - One-on-Ones Module
- Added OneOnOne model (manager schedules with employee)
- Added ActionItem model (tasks from 1:1 with responsible + deadline)
- Validations: manager ≠ employee, same-org checks
- Enums: status (scheduled/completed/cancelled/rescheduled)
- Scopes: upcoming, past, for_manager, for_employee
- Methods: complete!, overdue?
- Multi-tenancy enforcement

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.6 — Create Factories

**Duration**: 30 minutes

**Files**:
- `spec/factories/objectives.rb`
- `spec/factories/one_on_ones.rb`
- `spec/factories/action_items.rb`

**Implementation**:
```ruby
# spec/factories/objectives.rb
FactoryBot.define do
  factory :objective do
    association :organization
    association :manager, factory: :employee
    association :created_by, factory: :employee
    association :owner, factory: :employee

    title { "Q#{rand(1..4)} Objective - #{Faker::Lorem.words(3).join(' ')}" }
    description { Faker::Lorem.paragraph }
    status { :in_progress }
    priority { :medium }
    deadline { 3.months.from_now.to_date }

    trait :draft do
      status { :draft }
    end

    trait :completed do
      status { :completed }
      completed_at { 1.week.ago }
    end

    trait :overdue do
      status { :in_progress }
      deadline { 1.week.ago.to_date }
    end

    trait :high_priority do
      priority { :high }
    end
  end
end

# spec/factories/one_on_ones.rb
FactoryBot.define do
  factory :one_on_one do
    association :organization
    association :manager, factory: :employee
    association :employee, factory: :employee

    scheduled_at { 1.week.from_now }
    status { :scheduled }
    agenda { Faker::Lorem.sentence }

    trait :completed do
      status { :completed }
      completed_at { 1.day.ago }
      notes { Faker::Lorem.paragraph }
    end

    trait :upcoming do
      scheduled_at { 2.days.from_now }
      status { :scheduled }
    end

    trait :past do
      status { :completed }
      scheduled_at { 1.month.ago }
      completed_at { 1.month.ago }
    end
  end
end

# spec/factories/action_items.rb
FactoryBot.define do
  factory :action_item do
    association :one_on_one
    association :responsible, factory: :employee

    description { Faker::Lorem.sentence }
    deadline { 2.weeks.from_now.to_date }
    status { :pending }
    responsible_type { :employee }

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      completed_at { 1.day.ago.to_date }
      completion_notes { Faker::Lorem.paragraph }
    end

    trait :overdue do
      status { :pending }
      deadline { 1.week.ago.to_date }
    end

    trait :manager_responsible do
      responsible_type { :manager }
    end
  end
end
```

**Commit**:
```bash
git add spec/factories/objectives.rb spec/factories/one_on_ones.rb spec/factories/action_items.rb
git commit -m "test(factories): add factories for objectives, 1:1s, action items

Sprint 2.1 - Testing Infrastructure
- Added objective factory with traits (draft, completed, overdue)
- Added one_on_one factory with traits (upcoming, past)
- Added action_item factory with traits (overdue, completed)
- All factories include required associations

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.7 — Create Model Tests

**Duration**: 2 hours

**Target Coverage**: 80%+

**Files**:
- `spec/domains/objectives/models/objective_spec.rb`
- `spec/domains/one_on_ones/models/one_on_one_spec.rb`
- `spec/domains/one_on_ones/models/action_item_spec.rb`

**Test Structure** (for each model):
```ruby
RSpec.describe Objective, type: :model do
  describe 'associations' do
    # Test all belongs_to, has_many relationships
  end

  describe 'validations' do
    # Test presence, length, enum, custom validations
  end

  describe 'scopes' do
    # Test active, overdue, upcoming, for_manager, etc.
  end

  describe 'instance methods' do
    # Test complete!, overdue?, active?
  end

  describe 'multi-tenancy' do
    # Test acts_as_tenant scoping
  end
end
```

**Run Tests**:
```bash
bundle exec rspec spec/domains/objectives/
bundle exec rspec spec/domains/one_on_ones/
```

**Check Coverage**:
```bash
open coverage/index.html
# Verify objectives & one_on_ones domains show 80%+
```

**Commit**:
```bash
git add spec/domains/objectives/ spec/domains/one_on_ones/
git commit -m "test(models): add comprehensive tests for objectives and 1:1s

Sprint 2.1 - Model Tests
- Added Objective model tests (associations, validations, scopes, methods)
- Added OneOnOne model tests (complete flow, overdue detection)
- Added ActionItem model tests (status transitions, multi-tenancy)
- Coverage: 85% on new models
- All tests passing (619 -> 720+ examples)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.8 — Create Pundit Policies

**Duration**: 1 hour

**Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md lines 960-1025

**Files**:
- `app/policies/objective_policy.rb`
- `app/policies/one_on_one_policy.rb`
- `app/policies/action_item_policy.rb`

**Implementation**: COPY from architecture doc

**Test Files**:
- `spec/policies/objective_policy_spec.rb`
- `spec/policies/one_on_one_policy_spec.rb`
- `spec/policies/action_item_policy_spec.rb`

**Run Tests**:
```bash
bundle exec rspec spec/policies/
```

**Commit**:
```bash
git add app/policies/objective* app/policies/one_on_one* app/policies/action_item* spec/policies/
git commit -m "feat(auth): add Pundit policies for objectives and 1:1s

Sprint 2.1 - Authorization
- Added ObjectivePolicy (manager can CRUD team objectives)
- Added OneOnOnePolicy (manager can schedule/complete)
- Added ActionItemPolicy (responsible can complete)
- Scopes: HR sees all, managers see team, employees see own
- Policy tests with 100% coverage

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.9 — Create Service Objects

**Duration**: 1.5 hours

**Reference**: PERFORMANCE_LAYER_ARCHITECTURE.md lines 522-644

**Files**:
- `app/domains/objectives/services/objective_tracker.rb`
- `app/domains/one_on_ones/services/action_item_tracker.rb`

**Implementation**: COPY from architecture doc

**Test Files**:
- `spec/domains/objectives/services/objective_tracker_spec.rb`
- `spec/domains/one_on_ones/services/action_item_tracker_spec.rb`

**Run Tests**:
```bash
bundle exec rspec spec/domains/objectives/services/
bundle exec rspec spec/domains/one_on_ones/services/
```

**Commit**:
```bash
git add app/domains/*/services/ spec/domains/*/services/
git commit -m "feat(services): add objective and action item tracking services

Sprint 2.1 - Service Layer
- Added ObjectiveTracker (team progress, bulk complete)
- Added ActionItemTracker (my items, overdue detection, link objectives)
- Service tests with 80%+ coverage
- Transaction safety on bulk operations

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.10 — Create Controllers

**Duration**: 2 hours

**Files**:
- `app/controllers/manager/objectives_controller.rb`
- `app/controllers/manager/one_on_ones_controller.rb`
- `app/controllers/objectives_controller.rb`
- `app/controllers/one_on_ones_controller.rb`

**Routes** (`config/routes.rb`):
```ruby
# Manager namespace (full CRUD)
namespace :manager do
  resources :objectives
  resources :one_on_ones do
    member do
      patch :complete
    end
    resources :action_items, only: [:create, :update, :destroy]
  end
end

# Employee self-service (read-only)
resources :objectives, only: [:index, :show]
resources :one_on_ones, only: [:index, :show]
resources :action_items, only: [:index, :update] do
  member do
    patch :complete
  end
end
```

**Controller Implementation**:
```ruby
# app/controllers/manager/objectives_controller.rb
module Manager
  class ObjectivesController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_manager!
    before_action :set_objective, only: [:show, :edit, :update, :destroy, :complete]

    def index
      @objectives = policy_scope(Objective)
                     .for_manager(current_employee)
                     .includes(:owner, :manager)
                     .order(deadline: :asc)
                     .page(params[:page])

      # Filter by status
      @objectives = @objectives.where(status: params[:status]) if params[:status].present?
    end

    def new
      @objective = Objective.new(manager: current_employee, organization: current_organization)
      authorize @objective
    end

    def create
      @objective = Objective.new(objective_params.merge(
        organization: current_organization,
        manager: current_employee,
        created_by: current_employee
      ))

      authorize @objective

      if @objective.save
        redirect_to manager_objectives_path, notice: 'Objective created successfully'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def complete
      authorize @objective, :update?
      @objective.complete!
      redirect_to manager_objectives_path, notice: 'Objective marked as completed'
    end

    # ... other CRUD actions

    private

    def set_objective
      @objective = Objective.find(params[:id])
      authorize @objective
    end

    def objective_params
      params.require(:objective).permit(:title, :description, :owner_id, :owner_type, :deadline, :priority, :status)
    end

    def authorize_manager!
      unless current_employee.manager?
        redirect_to dashboard_path, alert: 'Manager access required'
      end
    end
  end
end
```

**Test Files**:
- `spec/requests/manager/objectives_spec.rb`
- `spec/requests/manager/one_on_ones_spec.rb`

**Run Tests**:
```bash
bundle exec rspec spec/requests/manager/
```

**Commit**:
```bash
git add app/controllers/manager/ config/routes.rb spec/requests/manager/
git commit -m "feat(controllers): add manager controllers for objectives and 1:1s

Sprint 2.1 - Manager Controllers
- Added Manager::ObjectivesController (full CRUD)
- Added Manager::OneOnOnesController (schedule, complete, action items)
- Authorization via Pundit (authorize @record)
- Routes: /manager/objectives, /manager/one_on_ones
- Request specs with authorization tests

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.11 — Create Basic Views

**Duration**: 2 hours

**Mobile-First Tailwind CSS**

**Files**:
- `app/views/manager/objectives/index.html.erb`
- `app/views/manager/objectives/new.html.erb`
- `app/views/manager/one_on_ones/index.html.erb`
- `app/views/manager/one_on_ones/new.html.erb`

**Example View** (`app/views/manager/objectives/index.html.erb`):
```erb
<div class="container mx-auto px-4 py-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Team Objectives</h1>
    <%= link_to "New Objective", new_manager_objective_path, class: "btn btn-primary" %>
  </div>

  <!-- Filter tabs -->
  <div class="mb-4 flex gap-2 overflow-x-auto">
    <%= link_to "All", manager_objectives_path, class: "btn btn-sm #{params[:status].blank? ? 'btn-primary' : 'btn-outline'}" %>
    <%= link_to "In Progress", manager_objectives_path(status: :in_progress), class: "btn btn-sm #{params[:status] == 'in_progress' ? 'btn-primary' : 'btn-outline'}" %>
    <%= link_to "Overdue", manager_objectives_path(status: :overdue), class: "btn btn-sm #{params[:status] == 'overdue' ? 'btn-primary' : 'btn-outline'}" %>
    <%= link_to "Completed", manager_objectives_path(status: :completed), class: "btn btn-sm #{params[:status] == 'completed' ? 'btn-primary' : 'btn-outline'}" %>
  </div>

  <!-- Objectives list -->
  <div class="space-y-4">
    <% @objectives.each do |objective| %>
      <div class="card bg-white dark:bg-gray-800 shadow-sm hover:shadow-md transition">
        <div class="card-body">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <h3 class="font-semibold text-lg text-gray-900 dark:text-white">
                <%= link_to objective.title, manager_objective_path(objective), class: "hover:text-blue-600" %>
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                <%= objective.owner.full_name %> • <%= objective.deadline.to_s(:long) %>
              </p>
            </div>
            <div class="ml-4">
              <%= status_badge(objective.status) %>
            </div>
          </div>

          <% if objective.overdue? %>
            <div class="mt-2 text-sm text-red-600 font-medium">
              ⚠️ Overdue by <%= distance_of_time_in_words(objective.deadline, Date.current) %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <%= paginate @objectives %>
</div>
```

**Commit**:
```bash
git add app/views/manager/objectives/ app/views/manager/one_on_ones/
git commit -m "feat(views): add basic views for manager objectives and 1:1s

Sprint 2.1 - Views
- Added manager objectives index (list with filters)
- Added manager objectives new/edit forms
- Added manager 1:1s index (upcoming + past tabs)
- Added manager 1:1s schedule form
- Mobile-first Tailwind CSS styling
- Status badges, overdue indicators

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### TASK 2.1.12 — Final Verification

**Duration**: 30 minutes

**Run Full Test Suite**:
```bash
bundle exec rspec
# Expected: 720-800 examples, 0 failures
```

**Check Coverage**:
```bash
open coverage/index.html
# Verify objectives & one_on_ones domains ≥80%
```

**Manual Testing**:
```bash
rails s
# Navigate to /manager/objectives
# Create objective
# Mark as complete
# Navigate to /manager/one_on_ones
# Schedule 1:1
```

**Database Verification**:
```bash
psql -d easy_rh_development -c "SELECT COUNT(*) FROM objectives;"
psql -d easy_rh_development -c "\d+ objectives" | grep Index
# Verify all indexes exist
```

**Git Status**:
```bash
git status
# Should be clean (all changes committed)
```

**Final Commit** (if any cleanup):
```bash
git add .
git commit -m "chore(sprint-2.1): final cleanup and verification

Sprint 2.1 Complete
- All tests passing (750+ examples)
- Coverage: 82% on new domains
- Database migrations verified
- Manual testing passed
- Ready for QA review

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 📊 Sprint 2.1 Completion Checklist

- [ ] Task 2.1.1: Domain structure created
- [ ] Task 2.1.2: Objectives migration
- [ ] Task 2.1.3: Objective model
- [ ] Task 2.1.4: One-on-Ones migrations
- [ ] Task 2.1.5: One-on-One models
- [ ] Task 2.1.6: Factories created
- [ ] Task 2.1.7: Model tests (80%+ coverage)
- [ ] Task 2.1.8: Pundit policies + tests
- [ ] Task 2.1.9: Service objects + tests
- [ ] Task 2.1.10: Controllers + request specs
- [ ] Task 2.1.11: Basic views (mobile-first)
- [ ] Task 2.1.12: Final verification

**When Complete**:
1. Run `bundle exec rspec` - Must be 100% passing
2. Run `open coverage/index.html` - Verify ≥80% on new code
3. Create `SPRINT_2.1_COMPLETION.md` documenting what was built
4. Hand off to @qa for validation

---

## 🔄 Handoff to QA

**Command**:
```
Load AGENT.qa.md and execute accordingly.
```

**QA Will Verify**:
- [ ] All tests passing
- [ ] Coverage ≥80% on new domains
- [ ] Multi-tenancy safety
- [ ] Authorization working correctly
- [ ] No N+1 queries on manager views
- [ ] Database indexes created
- [ ] Mobile-responsive UI

**After QA Approval**:
- Hand off to @architect for final validation
- Then proceed to Sprint 2.2 (Evaluations)

---

**End of Sprint 2.1 Instructions**

Next Sprint: **2.2 - Evaluations System** (6-8 hours)
