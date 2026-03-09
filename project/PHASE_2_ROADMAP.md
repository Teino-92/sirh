# PHASE 2 ROADMAP — PERFORMANCE LAYER

**Date**: 2026-02-16 (Sprint 2.4 added 2026-02-17)
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
| **2.4** | Dashboards + Polish | 4-6h | Sprint 2.3 | ✅ COMPLETE (architect validated 2026-02-17, 3 QA passes, 893 tests passing) |

**Total Estimated Effort**: 24-32 hours (3-4 working days)

---

## ✅ PHASE 2 — COMPLETE (architect sign-off 2026-02-17)

All sprints validated. Performance Layer is production-ready.
Authorization: full Pundit coverage on all domains.
Multi-tenancy: acts_as_tenant enforced throughout.
Data integrity: all state transitions atomic.
Next: Phase 3 — to be scoped by @architect.

---

## ✅ SPRINTS 1.7 → 2.3 — COMPLETE (2026-02-27)

**Sprint 1.7 — API Serializers** ✅
- `Api::V1::Concerns::Serializable` : module partagé entre tous les controllers API
- `serialize_employee` salary gated via `hr_or_admin?`
- `LeaveBalancesController#index` et `WorkSchedulesController#show/update` créés (routes orphelines)
- `TimeEntriesController`, `DashboardController`, `LeaveRequestsController` refactorisés
- Suppression des méthodes `_json` dupliquées dans chaque controller

**Sprint 1.8 — Rate Limiting** ✅
- rack-attack déjà en place (300rpm/IP, 5/20s login brute-force, 10/5min par email, 100rpm/user)
- Ajout : throttle LLM `hr_query/user` — 20 req/5min sur `POST /admin/hr_query`

**Sprint 2.1 — Shard Background Jobs** ✅
- `LeaveAccrualDispatcherJob` + `OrganizationLeaveAccrualJob` (queue `accruals`)
- `RttAccrualDispatcherJob` + `OrganizationRttAccrualJob` (queue `accruals`)
- `config/queue.yml` : 3 queues dédiées (schedulers, accruals, default)
- Traitement parallèle par org, idempotent (`discard_on RecordNotFound`)

**Sprint 2.2 — JSONB Schema Validation** ✅
- `JsonbValidatable` concern : allowed keys, required keys, type checks, boolean-safe (TrueClass/FalseClass)
- `Organization#settings` : type check sur clés connues, open-ended (extensible par design)
- `WorkSchedule#schedule_pattern` : format HH:MM-HH:MM par jour valide (`VALID_DAYS`)
- `TimeEntry#location` : structure lat/lng/accuracy/address si Hash
- 214 examples, 0 failures

**Sprint 2.3 — Audit Trail** ✅
- `paper_trail:install` + table `versions` + colonne `organization_id` (tenant-scoped)
- `has_paper_trail` : `LeaveBalance` (create/update), `LeaveRequest` (create/update/destroy), `EmployeeOnboarding` (create/update)
- `Admin::AuditLogsController` + `AuditLogPolicy` (hr_or_admin? uniquement)
- Vue `/admin/audit_log` : filtres type/événement/date, pagination kaminari, diff des changements
- Lien "Audit" dans nav admin desktop

---

## ✅ DIRECTION F — COMPLETE (architect sign-off 2026-02-27)

**Theme**: HR Query Engine — NL-to-Filters (IA pour admin/RH)

### F-1 — `HrQueryInterpreterService` ✅
- Appel Anthropic API (`claude-haiku-4-5-20251001`), timeout 15s, retry 2x
- JSON prefill `{"version":"1",` — forçage JSON structuré
- `PromptBuilder` : system prompt strict + schéma complet dans user message (jamais noms tables SQL)
- 7 exemples de spec (stub Faraday), tous verts

### F-2 — `HrQueryExecutorService` ✅
- Filtres JSON → scopes ActiveRecord (jamais SQL brut)
- Domaines : employee, leave (subquery SUM), evaluation, onboarding
- `MAX_RESULTS = 500`, salary re-gaté via `requester.hr_or_admin?`
- 8 exemples de spec, isolation tenant confirmée

### F-3 — `HrQueryCsvExporter` ✅
- Colonnes dynamiques selon `output.columns`, hérite `Exports::BaseCsvExporter`
- Double guard salary côté exporter

### F-4 — `HrQueryPolicy` + `Admin::HrQueriesController` ✅
- `show?`, `create?`, `export?` → `user.hr_or_admin?`
- 12 exemples de spec policy (admin ✅, hr ✅, manager ❌, employee ❌)

### F-5 — Vue + Stimulus controller ✅
- Textarea requête, loading state (spinner + disable button), résultats inline
- Lien "Requêtes IA" dans nav admin desktop + mobile
- Bouton "Exporter CSV" avec `filters` param JSON-encodé

**Architectural integrity:**
- SQL injection : impossible — le LLM ne produit jamais de SQL
- Schema leakage : prompt ne contient que les noms de champs filtres, pas les tables PostgreSQL
- Multi-tenancy : `acts_as_tenant` actif, `organization_id` jamais dans les filtres LLM
- Salary : `EmployeePolicy#see_salary?` re-vérifié en Ruby dans executor ET exporter

---

## ✅ DIRECTION D — COMPLETE (architect sign-off 2026-02-27)

**Theme**: Confidentialité salariale — droit du travail français

### D-1 — `EmployeePolicy#see_salary?` ✅
- Règle : `hr_or_admin? || user == record`
- Contractualise la confidentialité salariale au niveau domaine, pas routing

### D-2 — Vues conditionnées par policy ✅
- `admin/employees/show.html.erb` : bloc Rémunération sous `policy(@employee).see_salary?`
- `profile/show.html.erb` : guard `policy(@employee).see_salary? && gross_salary_cents > 0`

### D-3 — Spec `EmployeePolicy#see_salary?` ✅
- 6 cas : admin ✅, hr ✅, soi-même ✅, manager→subordonné ❌, manager→pair ❌, employé→pair ❌

### D-4 — `Admin::EmployeesController#show` : authorize explicite ✅
- `authorize @employee, :see_salary?` — couche métier indépendante du routing

**Architectural integrity:**
- Multi-tenancy: `set_employee` scoped via `organization.employees` — cross-org impossible
- Exports CSV: 0 colonne salaire confirmé
- QA observation medium: `edit`/`update` sans `authorize :see_salary?` — protégés par `Admin::BaseController`, non-bloquant. À traiter en Direction E.

---

## ✅ DIRECTION C — COMPLETE (architect sign-off 2026-02-27)

**Theme**: Complete onboarding domain + close remaining policy gaps

### C-1 — `GroupPoliciesPolicy` spec ✅
### C-2 — `OnboardingReview` model spec ✅
### C-3 — `PayrollController` authorization (`PayrollPolicy`) ✅
### C-4 — Payroll cadre_count N+1 fix ✅

**22 examples, 0 failures (Directions C+D combined)**

---

## ✅ DIRECTION E — COMPLETE (2026-02-27)

**Theme**: Clôturer les observations QA ouvertes + solidifier la surface salary

### E-1 — `authorize :see_salary?` dans `edit` et `update` (Medium QA obs.)
- `Admin::EmployeesController#edit` et `#update` : ajouter `authorize @employee, :see_salary?`
- Symétrie avec `show`, défense en profondeur sur la mutation salariale
- Spec : étendre `employee_policy_spec.rb` avec cas `edit?`/`update?` salary guard

### E-2 — `_form` : masquer les champs salaire si non autorisé
- `admin/employees/_form.html.erb` : envelopper le fieldset Rémunération dans `policy(@employee).see_salary?`
- Cohérence vue/controller : même guard partout

**Résultat:**
- [x] `edit` + `update` : `authorize :see_salary?` en place
- [x] `_form` : fieldset Rémunération conditionné par policy
- [x] Specs étendues, 9 examples, 0 failure

---

## ✅ DIRECTION B — COMPLETE (architect sign-off 2026-02-27)

**Streams validated:**

### B-1 — Pundit policy gaps closed ✅
- `OnboardingTaskPolicy` created: HR/admin sees all, manager scoped via `manager_id`, employee via `employee_id`
- `manager_of_onboarding?` guard: safe single-record check, no N+1
- 4 policy specs added (81 examples total, 0 failures):
  - `spec/policies/export_policy_spec.rb` (4 examples)
  - `spec/policies/employee_onboarding_policy_spec.rb` (17 examples)
  - `spec/policies/onboarding_task_policy_spec.rb` (7 examples)
  - `spec/policies/onboarding_template_policy_spec.rb` (10 examples)

### B-2 — Admin views ✅ (already in place, verified)
### B-3 — Initializer spec ✅ (already in place, verified)

**Architectural integrity confirmed:**
- All 4 onboarding controllers have corresponding Pundit policies
- Scope queries are single-JOIN — no N+1
- No domain leakage: policies in `app/policies/` (correct cross-cutting layer)
- `GroupPoliciesPolicy` unspecced — added to Direction C

---

## ✅ DIRECTION A — COMPLETE (architect sign-off 2026-02-27)

**Streams validated:**

### Stream 2 — TeamSchedulesController explicit org scoping ✅
- All cross-domain queries (`OneOnOne`, `Objective`, `TrainingAssignment`) scoped via `current_organization`
- `Organization` model: added `has_many :objectives`, `:one_on_ones`, `:trainings`, `:training_assignments (through: :trainings)`
- Zero cross-tenant leak risk confirmed

### Stream 1 — P1 tests for onboarding services ✅
- 4 spec files created (43 examples, 0 failures):
  - `spec/domains/onboarding/services/employee_onboarding_initializer_service_spec.rb` (16 examples)
  - `spec/domains/onboarding/services/employee_onboarding_progress_calculator_service_spec.rb` (9 examples)
  - `spec/domains/onboarding/services/employee_onboarding_integration_score_service_spec.rb` (9 examples)
  - `spec/jobs/employee_onboarding_score_refresh_job_spec.rb` (9 examples)
- Covers: 0%/100%, weight redistribution, tenant isolation, idempotency, skip-if-inactive
- Factory `spec/factories/onboardings.rb` with full traits

### Stream 3 — Full rename Onboarding → EmployeeOnboarding ✅
- Resolves real Zeitwerk namespace conflict (`class Onboarding` cannot be Ruby module)
- Migration: `rename_table :onboardings :employee_onboardings` + FK columns
- `Object.const_get` workaround eliminated
- Full sweep: model, services, job, policies, controllers, routes, views, seeds, factories, specs
- Both dev and test DBs migrated

**Architectural integrity confirmed:**
- Multi-tenancy: all scoping preserved post-rename
- No domain leakage introduced
- `has_many :training_assignments, through: :trainings` pattern correct (no direct org_id on table)
- Known acceptable: `app/jobs/employee_onboarding_score_refresh_job.rb` in `app/jobs/` (issue M5, non-blocking)

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
psql -d izi_rh_development -c "\d objectives"
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
psql -d izi_rh_development -c "\d one_on_ones"
psql -d izi_rh_development -c "\d action_items"
psql -d izi_rh_development -c "\d one_on_one_objectives"
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
psql -d izi_rh_development -c "SELECT COUNT(*) FROM objectives;"
psql -d izi_rh_development -c "\d+ objectives" | grep Index
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

---

# SPRINT 2.4 — DASHBOARDS + POLISH

**Objective**: Integrate Performance Layer into dashboard, add missing views, fix data integrity issue
**Complexity**: LOW-MEDIUM (view-heavy, one data integrity fix)
**Priority**: REQUIRED — completes Phase 2

**Architecture**: @architect validated 2026-02-17

---

## 🎯 Acceptance Criteria

### Data Integrity (non-negotiable pre-condition)
- [ ] `Manager::ObjectivesController#objective_params` does NOT permit `:status`
- [ ] Status transitions only via domain methods (`complete!`, etc.)

### Dashboard
- [ ] Manager dashboard shows: overdue objectives count, upcoming 1:1s (next 7 days), pending manager reviews count
- [ ] Employee dashboard shows: my active objectives count, my next 1:1, my pending training assignments count
- [ ] All new dashboard queries use `.includes()` — no N+1 queries
- [ ] Dashboard renders without error when employee has no objectives/1:1s/trainings (empty state, nil-safe)

### Views — Manager
- [ ] `manager/objectives/show` renders without ActionView::MissingTemplate
- [ ] `manager/objectives/new` and `edit` render and submit correctly
- [ ] `manager/one_on_ones/show`, `new`, `edit` render and submit correctly
- [ ] `manager/evaluations/show`, `new`, `edit` render and submit correctly

### Views — Employee (self-service)
- [ ] `objectives/index` renders current employee's objectives
- [ ] `one_on_ones/index` renders current employee's 1:1s
- [ ] `objectives_controller.rb` implements `index` and `show` actions (currently empty)
- [ ] `one_on_ones_controller.rb` implements `index` and `show` actions (currently empty)

### Tests
- [ ] `bundle exec rspec` → 0 failures
- [ ] Coverage does not regress below 28.12%

---

## 🛠️ IMPLEMENTATION STEPS

### TASK 2.4.1 — Fix ObjectivesController Params (Data Integrity)

**Duration**: 5 minutes

**File**: `app/controllers/manager/objectives_controller.rb`

**Problem** (line 58):
```ruby
def objective_params
  params.require(:objective).permit(:title, :description, :owner_id, :owner_type, :deadline, :priority, :status)
  # ❌ :status permits bypassing domain methods (same issue QA flagged in evaluations)
end
```

**Fix**:
```ruby
def objective_params
  params.require(:objective).permit(:title, :description, :owner_id, :owner_type, :deadline, :priority)
  # ✅ :status removed — use complete!, in_progress! etc. in dedicated actions
end
```

**Commit**:
```bash
git add app/controllers/manager/objectives_controller.rb
git commit -m "fix(objectives): remove :status from objective_params strong parameters

- Prevents status bypass via mass-assignment (same pattern as eval HIGH-1)
- Status transitions must use domain methods (complete!, blocked!, etc.)
- Data integrity: workflow guards enforced

Sprint 2.4 - Task 2.4.1"
```

---

### TASK 2.4.2 — Dashboard Controller: Performance Layer Integration

**Duration**: 45 minutes

**File**: `app/controllers/dashboard_controller.rb`

**Current state**: No Performance Layer data loaded at all.

**Add to `show` action** (after existing `@upcoming_leaves`):

```ruby
# Performance Layer (for all employees)
load_performance_layer_data

# ... keep existing calculate_weekly_hours private method
```

**Add private method**:
```ruby
def load_performance_layer_data
  # Employee: my active objectives
  @my_active_objectives_count = @employee.owned_objectives.active.count

  # Employee: my next 1:1
  @my_next_one_on_one = @employee.employee_one_on_ones
                                  .scheduled
                                  .where('scheduled_at >= ?', Time.current)
                                  .order(scheduled_at: :asc)
                                  .first

  # Employee: my pending training assignments
  @my_pending_training_count = @employee.training_assignments.pending.count

  # Manager-only additions
  if @employee.manager?
    # Overdue objectives for team
    @team_overdue_objectives_count = Objective
      .for_manager(@employee)
      .overdue
      .count

    # Upcoming 1:1s (next 7 days)
    @upcoming_one_on_ones = OneOnOne
      .where(manager: @employee)
      .scheduled
      .where(scheduled_at: Time.current..7.days.from_now)
      .includes(:employee)
      .order(scheduled_at: :asc)
      .limit(3)

    # Pending manager reviews (evaluations awaiting manager input)
    @pending_manager_reviews_count = Evaluation
      .for_manager(@employee)
      .manager_review_pending
      .count
  end
end
```

**Commit**:
```bash
git add app/controllers/dashboard_controller.rb
git commit -m "feat(dashboard): integrate Performance Layer widgets

- Employee: active objectives count, next 1:1, pending training count
- Manager: overdue objectives count, upcoming 1:1s (7 days), pending reviews count
- All queries nil-safe (no error when employee has no data)
- Eager loading on upcoming_one_on_ones (:employee)

Sprint 2.4 - Task 2.4.2"
```

---

### TASK 2.4.3 — Dashboard View: Add Performance Layer Widgets

**Duration**: 1.5 hours

**File**: `app/views/dashboard/show.html.erb`

**Add to the right column sidebar** (after existing Manager Pending Approvals block):

**For all employees — Performance summary widget**:
```erb
<%# Performance Layer - Employee Summary %>
<% if @my_active_objectives_count > 0 || @my_pending_training_count > 0 || @my_next_one_on_one %>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Ma performance</h2>
    <div class="space-y-3">
      <% if @my_active_objectives_count > 0 %>
        <%= link_to objectives_path, class: "flex items-center justify-between p-3 bg-blue-50 dark:bg-blue-900 rounded-lg hover:bg-blue-100 dark:hover:bg-blue-800 transition-colors" do %>
          <div class="flex items-center">
            <svg class="w-5 h-5 text-blue-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span class="text-sm font-medium text-gray-900 dark:text-gray-100">Objectifs actifs</span>
          </div>
          <span class="text-sm font-bold text-blue-700 dark:text-blue-300"><%= @my_active_objectives_count %></span>
        <% end %>
      <% end %>

      <% if @my_next_one_on_one %>
        <div class="flex items-center p-3 bg-purple-50 dark:bg-purple-900 rounded-lg">
          <svg class="w-5 h-5 text-purple-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z" />
          </svg>
          <div>
            <p class="text-sm font-medium text-gray-900 dark:text-gray-100">Prochain 1:1</p>
            <p class="text-xs text-gray-600 dark:text-gray-400"><%= l(@my_next_one_on_one.scheduled_at, format: :short) %></p>
          </div>
        </div>
      <% end %>

      <% if @my_pending_training_count > 0 %>
        <%= link_to training_assignments_path, class: "flex items-center justify-between p-3 bg-yellow-50 dark:bg-yellow-900 rounded-lg hover:bg-yellow-100 dark:hover:bg-yellow-800 transition-colors" do %>
          <div class="flex items-center">
            <svg class="w-5 h-5 text-yellow-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
            <span class="text-sm font-medium text-gray-900 dark:text-gray-100">Formations à compléter</span>
          </div>
          <span class="text-sm font-bold text-yellow-700 dark:text-yellow-300"><%= @my_pending_training_count %></span>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>
```

**For managers — Performance management widget** (add after existing manager pending approvals):
```erb
<%# Manager: Performance Management Actions %>
<% if @employee.manager? && (@team_overdue_objectives_count > 0 || @pending_manager_reviews_count > 0) %>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">Performance équipe</h2>
    <div class="space-y-3">
      <% if @team_overdue_objectives_count > 0 %>
        <%= link_to manager_objectives_path(status: :in_progress), class: "flex items-center justify-between p-3 bg-red-50 dark:bg-red-900 rounded-lg hover:bg-red-100 dark:hover:bg-red-800 transition-colors" do %>
          <div class="flex items-center">
            <svg class="w-5 h-5 text-red-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span class="text-sm font-medium text-gray-900 dark:text-gray-100">Objectifs en retard</span>
          </div>
          <span class="text-sm font-bold text-red-700 dark:text-red-300"><%= @team_overdue_objectives_count %></span>
        <% end %>
      <% end %>

      <% if @pending_manager_reviews_count > 0 %>
        <%= link_to manager_evaluations_path(status: :manager_review_pending), class: "flex items-center justify-between p-3 bg-orange-50 dark:bg-orange-900 rounded-lg hover:bg-orange-100 dark:hover:bg-orange-800 transition-colors" do %>
          <div class="flex items-center">
            <svg class="w-5 h-5 text-orange-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
            </svg>
            <span class="text-sm font-medium text-gray-900 dark:text-gray-100">Évaluations à compléter</span>
          </div>
          <span class="text-sm font-bold text-orange-700 dark:text-orange-300"><%= @pending_manager_reviews_count %></span>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>

<%# Manager: Upcoming 1:1s %>
<% if @employee.manager? && @upcoming_one_on_ones&.any? %>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <div class="flex justify-between items-center mb-4">
      <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">Prochains 1:1</h2>
      <%= link_to 'Voir tout', manager_one_on_ones_path, class: "text-sm text-indigo-600 hover:text-indigo-700" %>
    </div>
    <div class="space-y-3">
      <% @upcoming_one_on_ones.each do |meeting| %>
        <div class="flex items-center p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
          <div class="flex-1">
            <p class="text-sm font-medium text-gray-900 dark:text-gray-100"><%= meeting.employee.full_name %></p>
            <p class="text-xs text-gray-600 dark:text-gray-400"><%= l(meeting.scheduled_at, format: :short) %></p>
          </div>
          <%= link_to 'Voir', manager_one_on_one_path(meeting), class: "text-xs text-indigo-600 hover:text-indigo-700 font-medium" %>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

**Also add Performance Layer quick links** to the existing "Accès rapides" section:
```erb
<%# In the quick links section, add after existing links: %>
<%= link_to objectives_path, class: "flex items-center p-3 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors" do %>
  <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
  </svg>
  <span class="font-medium">Mes objectifs</span>
<% end %>
<%= link_to training_assignments_path, class: "flex items-center p-3 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors" do %>
  <svg class="w-5 h-5 mr-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
  </svg>
  <span class="font-medium">Mes formations</span>
<% end %>
```

**Commit**:
```bash
git add app/views/dashboard/show.html.erb
git commit -m "feat(dashboard): add Performance Layer widgets

- Employee: active objectives, next 1:1, pending training count
- Manager: overdue objectives, pending evaluations, upcoming 1:1s list
- Quick links: objectives, training assignments
- Mobile-first Tailwind CSS, dark mode compatible
- Nil-safe: no widgets rendered when data is empty

Sprint 2.4 - Task 2.4.3"
```

---

### TASK 2.4.4 — Implement Employee-Facing Controllers

**Duration**: 30 minutes

**Files**: `app/controllers/objectives_controller.rb`, `app/controllers/one_on_ones_controller.rb`

**Both are currently empty.** Implement:

**`app/controllers/objectives_controller.rb`**:
```ruby
class ObjectivesController < ApplicationController
  before_action :authenticate_employee!

  def index
    @objectives = policy_scope(Objective)
                   .for_owner(current_employee)
                   .includes(:manager)
                   .order(deadline: :asc)

    @objectives = @objectives.where(status: params[:status]) if params[:status].present?
  end

  def show
    @objective = Objective.find(params[:id])
    authorize @objective
  end
end
```

**`app/controllers/one_on_ones_controller.rb`**:
```ruby
class OneOnOnesController < ApplicationController
  before_action :authenticate_employee!

  def index
    @one_on_ones = policy_scope(OneOnOne)
                    .where(employee: current_employee)
                    .includes(:manager)
                    .order(scheduled_at: :desc)
  end

  def show
    @one_on_one = OneOnOne.find(params[:id])
    authorize @one_on_one
  end
end
```

**Commit**:
```bash
git add app/controllers/objectives_controller.rb app/controllers/one_on_ones_controller.rb
git commit -m "feat(controllers): implement employee-facing objectives and one_on_ones controllers

- ObjectivesController: index (employee's own objectives) + show
- OneOnOnesController: index (employee's 1:1s) + show
- policy_scope enforces read-only access
- Eager loading: includes(:manager)

Sprint 2.4 - Task 2.4.4"
```

---

### TASK 2.4.5 — Create Employee-Facing Views

**Duration**: 1 hour

**Files to create**:
- `app/views/objectives/index.html.erb`
- `app/views/objectives/show.html.erb`
- `app/views/one_on_ones/index.html.erb`
- `app/views/one_on_ones/show.html.erb`

**`app/views/objectives/index.html.erb`**:
```erb
<div class="max-w-4xl mx-auto px-4 py-6">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">Mes objectifs</h1>
  </div>

  <div class="flex gap-2 mb-4 overflow-x-auto pb-2">
    <%= link_to 'Tous', objectives_path, class: "btn btn-sm #{params[:status].blank? ? 'btn-primary' : 'btn-outline'}" %>
    <%= link_to 'En cours', objectives_path(status: :in_progress), class: "btn btn-sm #{params[:status] == 'in_progress' ? 'btn-primary' : 'btn-outline'}" %>
    <%= link_to 'Complétés', objectives_path(status: :completed), class: "btn btn-sm #{params[:status] == 'completed' ? 'btn-primary' : 'btn-outline'}" %>
  </div>

  <% if @objectives.any? %>
    <div class="space-y-4">
      <% @objectives.each do |objective| %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <h3 class="font-semibold text-lg text-gray-900 dark:text-gray-100">
                <%= link_to objective.title, objective_path(objective), class: "hover:text-indigo-600" %>
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                Manager : <%= objective.manager.full_name %> &bull;
                Échéance : <%= l(objective.deadline, format: :short) %>
              </p>
            </div>
            <span class="ml-3 px-2 py-1 text-xs font-medium rounded bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
              <%= objective.status.humanize %>
            </span>
          </div>
          <% if objective.overdue? %>
            <p class="mt-2 text-sm text-red-600 font-medium">
              En retard de <%= distance_of_time_in_words(objective.deadline, Date.current) %>
            </p>
          <% end %>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-12 text-gray-500 dark:text-gray-400">
      <p class="text-lg">Aucun objectif</p>
      <p class="text-sm mt-1">Votre manager n'a pas encore défini d'objectifs pour vous.</p>
    </div>
  <% end %>
</div>
```

**`app/views/objectives/show.html.erb`**:
```erb
<div class="max-w-3xl mx-auto px-4 py-6">
  <%= link_to "&larr; Mes objectifs".html_safe, objectives_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>

  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <div class="flex justify-between items-start mb-4">
      <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100"><%= @objective.title %></h1>
      <span class="px-3 py-1 text-sm font-medium rounded-full bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
        <%= @objective.status.humanize %>
      </span>
    </div>

    <% if @objective.description.present? %>
      <p class="text-gray-700 dark:text-gray-300 mb-6"><%= @objective.description %></p>
    <% end %>

    <dl class="grid grid-cols-2 gap-4 text-sm">
      <div>
        <dt class="font-medium text-gray-600 dark:text-gray-400">Priorité</dt>
        <dd class="text-gray-900 dark:text-gray-100 mt-1"><%= @objective.priority.humanize %></dd>
      </div>
      <div>
        <dt class="font-medium text-gray-600 dark:text-gray-400">Échéance</dt>
        <dd class="text-gray-900 dark:text-gray-100 mt-1 <%= @objective.overdue? ? 'text-red-600' : '' %>">
          <%= l(@objective.deadline, format: :long) %>
          <% if @objective.overdue? %><span class="ml-1 text-xs">(en retard)</span><% end %>
        </dd>
      </div>
      <div>
        <dt class="font-medium text-gray-600 dark:text-gray-400">Manager</dt>
        <dd class="text-gray-900 dark:text-gray-100 mt-1"><%= @objective.manager.full_name %></dd>
      </div>
    </dl>
  </div>
</div>
```

**`app/views/one_on_ones/index.html.erb`**:
```erb
<div class="max-w-4xl mx-auto px-4 py-6">
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Mes 1:1</h1>

  <% if @one_on_ones.any? %>
    <div class="space-y-4">
      <% @one_on_ones.each do |meeting| %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="font-semibold text-gray-900 dark:text-gray-100">
                1:1 avec <%= meeting.manager.full_name %>
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
                <%= l(meeting.scheduled_at, format: :long) %>
              </p>
              <% if meeting.agenda.present? %>
                <p class="text-sm text-gray-700 dark:text-gray-300 mt-2"><%= meeting.agenda %></p>
              <% end %>
            </div>
            <span class="px-2 py-1 text-xs font-medium rounded bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
              <%= meeting.status.humanize %>
            </span>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-12 text-gray-500 dark:text-gray-400">
      <p class="text-lg">Aucun 1:1 planifié</p>
      <p class="text-sm mt-1">Votre manager planifiera bientôt un 1:1 avec vous.</p>
    </div>
  <% end %>
</div>
```

**`app/views/one_on_ones/show.html.erb`**:
```erb
<div class="max-w-3xl mx-auto px-4 py-6">
  <%= link_to "&larr; Mes 1:1".html_safe, one_on_ones_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>

  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <div class="flex justify-between items-start mb-4">
      <h1 class="text-xl font-bold text-gray-900 dark:text-gray-100">
        1:1 avec <%= @one_on_one.manager.full_name %>
      </h1>
      <span class="px-3 py-1 text-sm font-medium rounded-full bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
        <%= @one_on_one.status.humanize %>
      </span>
    </div>

    <dl class="space-y-4 text-sm">
      <div>
        <dt class="font-medium text-gray-600 dark:text-gray-400">Date</dt>
        <dd class="text-gray-900 dark:text-gray-100 mt-1"><%= l(@one_on_one.scheduled_at, format: :long) %></dd>
      </div>
      <% if @one_on_one.agenda.present? %>
        <div>
          <dt class="font-medium text-gray-600 dark:text-gray-400">Agenda</dt>
          <dd class="text-gray-900 dark:text-gray-100 mt-1"><%= @one_on_one.agenda %></dd>
        </div>
      <% end %>
      <% if @one_on_one.notes.present? %>
        <div>
          <dt class="font-medium text-gray-600 dark:text-gray-400">Notes</dt>
          <dd class="text-gray-700 dark:text-gray-300 mt-1 whitespace-pre-wrap"><%= @one_on_one.notes %></dd>
        </div>
      <% end %>
    </dl>
  </div>
</div>
```

**Commit**:
```bash
git add app/views/objectives/ app/views/one_on_ones/
git commit -m "feat(views): add employee-facing objectives and one_on_ones views

- objectives/index: list with status filter, overdue indicator
- objectives/show: title, description, priority, deadline, manager
- one_on_ones/index: list with manager name, date, agenda
- one_on_ones/show: detail with notes (post-completion)
- Empty states with helpful messages
- Mobile-first, dark mode compatible

Sprint 2.4 - Task 2.4.5"
```

---

### TASK 2.4.6 — Create Manager Views: Objectives show/new/edit

**Duration**: 1 hour

**Files to create**:
- `app/views/manager/objectives/show.html.erb`
- `app/views/manager/objectives/new.html.erb`
- `app/views/manager/objectives/edit.html.erb`
- `app/views/manager/objectives/_form.html.erb`

**`app/views/manager/objectives/_form.html.erb`**:
```erb
<%= form_with(model: [:manager, objective], class: "space-y-4") do |f| %>
  <% if objective.errors.any? %>
    <div class="bg-red-50 dark:bg-red-900 border border-red-300 dark:border-red-600 rounded p-4">
      <% objective.errors.full_messages.each do |msg| %>
        <p class="text-sm text-red-700 dark:text-red-300"><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= f.label :title, "Titre", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.text_field :title, class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div>
    <%= f.label :description, "Description", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.text_area :description, rows: 4, class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
    <div>
      <%= f.label :owner_id, "Employé concerné", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
      <%= f.hidden_field :owner_type, value: "Employee" %>
      <%= f.collection_select :owner_id,
            policy_scope(Employee).where.not(id: current_employee.id).order(:first_name),
            :id, :full_name,
            { prompt: "Sélectionner un employé" },
            class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
    </div>

    <div>
      <%= f.label :priority, "Priorité", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
      <%= f.select :priority,
            [['Faible', 'low'], ['Moyenne', 'medium'], ['Haute', 'high'], ['Critique', 'critical']],
            {},
            class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
    </div>
  </div>

  <div>
    <%= f.label :deadline, "Échéance", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.date_field :deadline, class: "rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="flex gap-3 pt-4">
    <%= f.submit "Enregistrer", class: "btn btn-primary" %>
    <%= link_to "Annuler", manager_objectives_path, class: "btn btn-outline" %>
  </div>
<% end %>
```

**`app/views/manager/objectives/new.html.erb`**:
```erb
<div class="max-w-2xl mx-auto px-4 py-6">
  <%= link_to "&larr; Objectifs".html_safe, manager_objectives_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Nouvel objectif</h1>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <%= render 'form', objective: @objective %>
  </div>
</div>
```

**`app/views/manager/objectives/edit.html.erb`**:
```erb
<div class="max-w-2xl mx-auto px-4 py-6">
  <%= link_to "&larr; Objectifs".html_safe, manager_objectives_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Modifier l'objectif</h1>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <%= render 'form', objective: @objective %>
  </div>
</div>
```

**`app/views/manager/objectives/show.html.erb`**:
```erb
<div class="max-w-3xl mx-auto px-4 py-6">
  <%= link_to "&larr; Objectifs".html_safe, manager_objectives_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>

  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <div class="flex justify-between items-start mb-6">
      <div class="flex-1">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100"><%= @objective.title %></h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          <%= @objective.owner.full_name %> &bull;
          Échéance : <%= l(@objective.deadline, format: :long) %>
        </p>
      </div>
      <span class="ml-3 px-3 py-1 text-sm font-medium rounded-full bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
        <%= @objective.status.humanize %>
      </span>
    </div>

    <% if @objective.description.present? %>
      <p class="text-gray-700 dark:text-gray-300 mb-6"><%= @objective.description %></p>
    <% end %>

    <div class="flex gap-3">
      <%= link_to "Modifier", edit_manager_objective_path(@objective), class: "btn btn-outline btn-sm" %>
      <% unless @objective.completed? || @objective.cancelled? %>
        <%= button_to "Marquer complété", complete_manager_objective_path(@objective), method: :patch, class: "btn btn-primary btn-sm",
              data: { confirm: "Marquer cet objectif comme complété ?" } %>
      <% end %>
      <%= button_to "Supprimer", manager_objective_path(@objective), method: :delete, class: "btn btn-error btn-sm",
            data: { confirm: "Supprimer cet objectif ?" } %>
    </div>
  </div>
</div>
```

**Note**: The `complete` action doesn't exist yet in the controller. Add it:

```ruby
# In Manager::ObjectivesController, add:
def complete
  authorize @objective, :update?
  @objective.complete!
  redirect_to manager_objectives_path, notice: 'Objectif complété'
rescue => e
  redirect_to manager_objective_path(@objective), alert: e.message
end
```

And in routes (add `member` block to objectives):
```ruby
namespace :manager do
  resources :objectives do
    member do
      patch :complete
    end
  end
  # ...
end
```

**Commit**:
```bash
git add app/views/manager/objectives/ app/controllers/manager/objectives_controller.rb config/routes.rb
git commit -m "feat(views): add manager objectives show/new/edit views

- show: objective details, complete + delete actions
- new/edit: form with employee selector, priority, deadline
- complete action added to controller and routes
- Form partial shared between new/edit
- Mobile-first Tailwind CSS, dark mode

Sprint 2.4 - Task 2.4.6"
```

---

### TASK 2.4.7 — Create Manager Views: One-On-Ones show/new/edit

**Duration**: 1 hour

**Files to create**:
- `app/views/manager/one_on_ones/_form.html.erb`
- `app/views/manager/one_on_ones/new.html.erb`
- `app/views/manager/one_on_ones/edit.html.erb`
- `app/views/manager/one_on_ones/show.html.erb`

**`app/views/manager/one_on_ones/_form.html.erb`**:
```erb
<%= form_with(model: [:manager, one_on_one], class: "space-y-4") do |f| %>
  <% if one_on_one.errors.any? %>
    <div class="bg-red-50 dark:bg-red-900 border border-red-300 rounded p-4">
      <% one_on_one.errors.full_messages.each do |msg| %>
        <p class="text-sm text-red-700 dark:text-red-300"><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= f.label :employee_id, "Employé", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.collection_select :employee_id,
          policy_scope(Employee).where.not(id: current_employee.id).order(:first_name),
          :id, :full_name,
          { prompt: "Sélectionner un employé" },
          class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div>
    <%= f.label :scheduled_at, "Date et heure", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.datetime_local_field :scheduled_at, class: "rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div>
    <%= f.label :agenda, "Agenda (optionnel)", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.text_area :agenda, rows: 3, class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="flex gap-3 pt-4">
    <%= f.submit "Enregistrer", class: "btn btn-primary" %>
    <%= link_to "Annuler", manager_one_on_ones_path, class: "btn btn-outline" %>
  </div>
<% end %>
```

**`app/views/manager/one_on_ones/new.html.erb`**:
```erb
<div class="max-w-2xl mx-auto px-4 py-6">
  <%= link_to "&larr; 1:1".html_safe, manager_one_on_ones_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Planifier un 1:1</h1>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <%= render 'form', one_on_one: @one_on_one %>
  </div>
</div>
```

**`app/views/manager/one_on_ones/edit.html.erb`**:
```erb
<div class="max-w-2xl mx-auto px-4 py-6">
  <%= link_to "&larr; 1:1".html_safe, manager_one_on_ones_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Modifier le 1:1</h1>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <%= render 'form', one_on_one: @one_on_one %>
  </div>
</div>
```

**`app/views/manager/one_on_ones/show.html.erb`**:
```erb
<div class="max-w-3xl mx-auto px-4 py-6">
  <%= link_to "&larr; 1:1".html_safe, manager_one_on_ones_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>

  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <div class="flex justify-between items-start mb-6">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-gray-100">
          1:1 avec <%= @one_on_one.employee.full_name %>
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          <%= l(@one_on_one.scheduled_at, format: :long) %>
        </p>
      </div>
      <span class="px-3 py-1 text-sm font-medium rounded-full bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
        <%= @one_on_one.status.humanize %>
      </span>
    </div>

    <% if @one_on_one.agenda.present? %>
      <div class="mb-6">
        <h2 class="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">Agenda</h2>
        <p class="text-gray-700 dark:text-gray-300"><%= @one_on_one.agenda %></p>
      </div>
    <% end %>

    <% if @one_on_one.notes.present? %>
      <div class="mb-6">
        <h2 class="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">Notes</h2>
        <p class="text-gray-700 dark:text-gray-300 whitespace-pre-wrap"><%= @one_on_one.notes %></p>
      </div>
    <% end %>

    <div class="flex gap-3">
      <% if @one_on_one.scheduled? %>
        <%= button_to "Marquer complété", complete_manager_one_on_one_path(@one_on_one), method: :patch, class: "btn btn-primary btn-sm",
              data: { confirm: "Marquer ce 1:1 comme complété ?" } %>
        <%= link_to "Modifier", edit_manager_one_on_one_path(@one_on_one), class: "btn btn-outline btn-sm" %>
      <% end %>
    </div>
  </div>
</div>
```

**Commit**:
```bash
git add app/views/manager/one_on_ones/
git commit -m "feat(views): add manager one_on_ones show/new/edit views

- show: 1:1 details, agenda, notes, complete action
- new/edit: form with employee selector, datetime, agenda
- Form partial shared between new/edit
- Mobile-first, dark mode

Sprint 2.4 - Task 2.4.7"
```

---

### TASK 2.4.8 — Create Manager Views: Evaluations show/new/edit

**Duration**: 1 hour

**Files to create**:
- `app/views/manager/evaluations/_form.html.erb`
- `app/views/manager/evaluations/new.html.erb`
- `app/views/manager/evaluations/edit.html.erb`
- `app/views/manager/evaluations/show.html.erb`

**`app/views/manager/evaluations/_form.html.erb`**:
```erb
<%= form_with(model: [:manager, evaluation], class: "space-y-4") do |f| %>
  <% if evaluation.errors.any? %>
    <div class="bg-red-50 dark:bg-red-900 border border-red-300 rounded p-4">
      <% evaluation.errors.full_messages.each do |msg| %>
        <p class="text-sm text-red-700 dark:text-red-300"><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= f.label :employee_id, "Employé", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
    <%= f.collection_select :employee_id,
          policy_scope(Employee).where.not(id: current_employee.id).order(:first_name),
          :id, :full_name,
          { prompt: "Sélectionner un employé" },
          class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
  </div>

  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
    <div>
      <%= f.label :period_start, "Début de période", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
      <%= f.date_field :period_start, class: "rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
    </div>
    <div>
      <%= f.label :period_end, "Fin de période", class: "block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1" %>
      <%= f.date_field :period_end, class: "rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
    </div>
  </div>

  <div class="flex gap-3 pt-4">
    <%= f.submit "Créer l'évaluation", class: "btn btn-primary" %>
    <%= link_to "Annuler", manager_evaluations_path, class: "btn btn-outline" %>
  </div>
<% end %>
```

**`app/views/manager/evaluations/new.html.erb`**:
```erb
<div class="max-w-2xl mx-auto px-4 py-6">
  <%= link_to "&larr; Évaluations".html_safe, manager_evaluations_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Nouvelle évaluation</h1>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <%= render 'form', evaluation: @evaluation %>
  </div>
</div>
```

**`app/views/manager/evaluations/edit.html.erb`**:
```erb
<div class="max-w-2xl mx-auto px-4 py-6">
  <%= link_to "&larr; Évaluations".html_safe, manager_evaluations_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>
  <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-6">Modifier l'évaluation</h1>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <%= render 'form', evaluation: @evaluation %>
  </div>
</div>
```

**`app/views/manager/evaluations/show.html.erb`**:
```erb
<div class="max-w-3xl mx-auto px-4 py-6">
  <%= link_to "&larr; Évaluations".html_safe, manager_evaluations_path, class: "text-sm text-gray-600 dark:text-gray-400 hover:text-indigo-600 mb-4 inline-block" %>

  <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
    <div class="flex justify-between items-start mb-6">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-gray-100">
          Évaluation — <%= @evaluation.employee.full_name %>
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">
          <%= l(@evaluation.period_start, format: :short) %> &ndash; <%= l(@evaluation.period_end, format: :long) %>
        </p>
      </div>
      <span class="px-3 py-1 text-sm font-medium rounded-full bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
        <%= @evaluation.status.humanize %>
      </span>
    </div>

    <% if @evaluation.self_review.present? %>
      <div class="mb-6 p-4 bg-blue-50 dark:bg-blue-900 rounded-lg">
        <h2 class="text-sm font-semibold text-blue-800 dark:text-blue-200 mb-2">Auto-évaluation</h2>
        <p class="text-gray-700 dark:text-gray-300 text-sm whitespace-pre-wrap"><%= @evaluation.self_review %></p>
      </div>
    <% end %>

    <% if @evaluation.manager_review.present? %>
      <div class="mb-6 p-4 bg-green-50 dark:bg-green-900 rounded-lg">
        <h2 class="text-sm font-semibold text-green-800 dark:text-green-200 mb-2">Évaluation manager</h2>
        <p class="text-gray-700 dark:text-gray-300 text-sm whitespace-pre-wrap"><%= @evaluation.manager_review %></p>
      </div>
    <% end %>

    <%# Manager review form (when self-review submitted and manager review pending) %>
    <% if @evaluation.manager_review_pending? %>
      <div class="mt-6 p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
        <h2 class="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-3">Soumettre votre évaluation</h2>
        <%= form_with url: submit_manager_review_manager_evaluation_path(@evaluation), method: :patch, class: "space-y-4" do |f| %>
          <%= f.text_area :manager_review, rows: 6, placeholder: "Votre évaluation...",
                class: "w-full rounded-lg border-gray-300 dark:border-gray-600 dark:bg-gray-700 shadow-sm focus:border-indigo-500 focus:ring-indigo-500" %>
          <%= f.submit "Soumettre et compléter", class: "btn btn-primary" %>
        <% end %>
      </div>
    <% end %>

    <% if @evaluation.fully_reviewed? && @evaluation.active? %>
      <div class="mt-6">
        <%= button_to "Finaliser l'évaluation", complete_manager_evaluation_path(@evaluation), method: :patch, class: "btn btn-primary",
              data: { confirm: "Finaliser cette évaluation ?" } %>
      </div>
    <% end %>
  </div>
</div>
```

**Commit**:
```bash
git add app/views/manager/evaluations/
git commit -m "feat(views): add manager evaluations show/new/edit views

- show: self-review, manager review, submit manager review inline form
- new/edit: form with employee selector, period dates
- Complete/finalize actions surfaced in show view
- Mobile-first, dark mode, French locale

Sprint 2.4 - Task 2.4.8"
```

---

### TASK 2.4.9 — Final Verification

**Duration**: 30 minutes

**Run full test suite**:
```bash
bundle exec rspec
# Expected: ≥893 examples, 0 failures
```

**Coverage check**:
```bash
open coverage/index.html
# Verify ≥28.12% overall
```

**Manual navigation check**:
```bash
rails s
# Test:
# - /dashboard (employee + manager views)
# - /manager/objectives (index + new + show + edit)
# - /manager/one_on_ones (index + new + show)
# - /manager/evaluations (index + new + show)
# - /objectives (employee)
# - /one_on_ones (employee)
```

**Final commit**:
```bash
git add .
git commit -m "chore(sprint-2.4): final verification

Sprint 2.4 Complete - Dashboards + Polish
- Data integrity: :status removed from objective_params
- Dashboard: Performance Layer fully integrated (employee + manager)
- Manager views: show/new/edit for objectives, 1:1s, evaluations
- Employee views: objectives + one_on_ones index + show
- 893+ examples, 0 failures
- Coverage ≥28.12%

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 📊 Sprint 2.4 Completion Checklist

- [ ] Task 2.4.1: Remove `:status` from ObjectivesController params
- [ ] Task 2.4.2: DashboardController Performance Layer integration
- [ ] Task 2.4.3: Dashboard view widgets (employee + manager)
- [ ] Task 2.4.4: Employee-facing objectives + one_on_ones controllers
- [ ] Task 2.4.5: Employee-facing views (objectives + one_on_ones)
- [ ] Task 2.4.6: Manager objectives show/new/edit views + complete action
- [ ] Task 2.4.7: Manager one_on_ones show/new/edit views
- [ ] Task 2.4.8: Manager evaluations show/new/edit views
- [ ] Task 2.4.9: Final verification (tests + coverage + manual)

**When Complete**:
1. Run `bundle exec rspec` — must be 0 failures
2. Tag @qa for validation
3. After @qa approval → @architect final validation
4. Phase 2 (Performance Layer) marked COMPLETE

---

## 🔄 Handoff to QA

After completing all tasks:
```
Load AGENT.qa.md and execute accordingly.
```

**QA will verify**:
- [ ] Tests passing (0 failures)
- [ ] No N+1 queries on dashboard (new performance queries)
- [ ] Multi-tenancy: employee can only see own objectives/1:1s
- [ ] Authorization: employee cannot access manager routes
- [ ] Dashboard widgets render correctly with empty data
- [ ] Forms submit correctly (objectives, 1:1s, evaluations)
- [ ] `:status` no longer accepted via mass-assignment on objectives

**After QA Approval**: Hand off to @architect for final validation → Phase 2 COMPLETE

---

**End of Sprint 2.4 Instructions**
**This completes Phase 2 — Performance Layer**
**Next Phase**: Return to `project/DEVELOPER_ROADMAP.md` Sprints 1.7+ (API Serializers, Rate Limiting, JSONB Validation, Audit Trail)
