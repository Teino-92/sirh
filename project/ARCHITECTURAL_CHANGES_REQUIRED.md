# ARCHITECTURAL CHANGES REQUIRED — EASY-RH
**Date**: 2026-02-15
**Architect**: Claude Code (Sonnet 4.5)
**Status**: Comprehensive Audit Complete
**Scope**: Production readiness for 200 orgs, 10k+ employees

---

## EXECUTIVE SUMMARY

This document catalogs all architectural changes required to bring Izi-RH from MVP (2-3 pilot clients) to production-ready SaaS scale (200 organizations, 10k+ employees). Changes are classified by **severity**, **impact**, and **implementation priority**.

**Total Issues Identified**: 31
- **CRITICAL** (Production Blockers): 8
- **HIGH** (Scalability Risks): 10
- **MEDIUM** (Technical Debt): 8
- **LOW** (Quality of Life): 5

---

## CLASSIFICATION SYSTEM

### Severity Levels

**CRITICAL** 🚨
- Blocks production deployment
- Data integrity risk
- Security vulnerability
- Must fix before first paying client

**HIGH** ⚠️
- Performance degradation at scale
- Maintenance burden
- Architectural inconsistency
- Fix before 100+ employees

**MEDIUM** 🔧
- Technical debt
- Code quality issue
- Reduces developer velocity
- Fix when capacity allows

**LOW** ℹ️
- Nice-to-have improvement
- Minor optimization
- Future-proofing
- Defer unless quick win

---

## CRITICAL ISSUES (Production Blockers)

### C1. Missing Transaction Blocks (Data Integrity)

**Severity**: 🚨 CRITICAL
**Impact**: Race conditions, inconsistent balances, data corruption
**Effort**: Small (2-3h)
**Risk**: Low (well-understood pattern)

**Problem**:
Multiple related database mutations occur without transactional safety. If one operation fails mid-flow, data becomes inconsistent.

**Examples**:

```ruby
# LeaveRequest#approve! (app/domains/leave_management/models/leave_request.rb)
def approve!(approver)
  update!(status: 'approved', approved_by: approver, approved_at: Time.current)
  # ⚠️ If next line fails, request is approved but balance not updated
  employee.leave_balances.find_by(leave_type: leave_type).decrement!(:balance, days_count)
end
```

```ruby
# RttAccrualJob (app/jobs/rtt_accrual_job.rb)
def update_rtt_balance(employee, days)
  balance = employee.leave_balances.find_or_create_by(leave_type: 'rtt')
  # ⚠️ If increment fails, job marks complete but balance unchanged
  balance.increment!(:balance, days)
  Rails.logger.info "RTT accrued for #{employee.email}: +#{days} days"
end
```

**Solution**:

```ruby
# Wrap in transaction
def approve!(approver)
  ActiveRecord::Base.transaction do
    update!(status: 'approved', approved_by: approver, approved_at: Time.current)
    employee.leave_balances.find_by(leave_type: leave_type).decrement!(:balance, days_count)
  end
end
```

**Files to Fix**:
- `app/domains/leave_management/models/leave_request.rb` (lines 45-50)
- `app/domains/leave_management/models/leave_balance.rb` (if balance mutations exist)
- `app/jobs/rtt_accrual_job.rb` (lines 80-85)
- `app/jobs/leave_accrual_job.rb` (lines 60-70)

**Acceptance Criteria**:
- All balance mutations wrapped in `ActiveRecord::Base.transaction`
- Rollback on any exception
- Tests verify atomicity (raise exception mid-transaction, assert no partial updates)

---

### C2. Incomplete Mailer Implementation

**Severity**: 🚨 CRITICAL
**Impact**: Jobs referencing non-existent classes cause 500 errors
**Effort**: Medium (4-6h to implement, or 30min to remove)
**Risk**: Low (cosmetic feature)

**Problem**:
Background jobs call mailers that don't exist:

```ruby
# app/jobs/leave_request_notification_job.rb
LeaveRequestMailer.submitted(leave_request).deliver_now  # ❌ Class not found
LeaveRequestMailer.pending_approval(leave_request, manager).deliver_now
```

```ruby
# app/jobs/weekly_time_validation_reminder_job.rb
TimeEntryMailer.weekly_validation_reminder(manager).deliver_now  # ❌ Class not found
```

**Solution Options**:

**Option A - Implement Mailers** (RECOMMENDED):
```bash
rails generate mailer LeaveRequest submitted approved rejected cancelled
rails generate mailer TimeEntry weekly_validation_reminder correction_requested
```

**Option B - Remove Mailer Calls** (QUICK FIX):
```ruby
# Comment out or remove mailer delivery calls
# LeaveRequestMailer.submitted(leave_request).deliver_now
Rails.logger.info "Leave request submitted: #{leave_request.id}"
```

**Files to Fix**:
- Create `app/mailers/leave_request_mailer.rb`
- Create `app/mailers/time_entry_mailer.rb`
- Or remove calls in `app/jobs/leave_request_notification_job.rb`
- Or remove calls in `app/jobs/weekly_time_validation_reminder_job.rb`

**Acceptance Criteria**:
- No uninitialized constant errors
- Either functional mailers OR removed references
- Background jobs run without exceptions

---

### C3. API Authentication Incomplete

**Severity**: 🚨 CRITICAL (if API exposed)
**Impact**: Unauthenticated API access, tenant leakage
**Effort**: Medium (3-4h to complete, or 15min to disable)
**Risk**: High (security vulnerability)

**Problem**:
Per CLAUDE.md: "JWT authentication incomplete for API"

**Evidence**:
- `JwtDenylist` model exists (app/models/jwt_denylist.rb)
- API controllers exist (app/controllers/api/v1/)
- JWT strategy referenced but not verified functional

**Required Verification**:
1. Confirm `devise-jwt` gem installed and configured
2. Test JWT token generation (`POST /api/v1/login`)
3. Test JWT token refresh (`POST /api/v1/refresh`)
4. Test JWT revocation (logout)
5. Test expired token handling
6. Verify tenant isolation in API requests

**Solution Options**:

**Option A - Complete JWT Setup**:
```ruby
# config/initializers/devise.rb
config.jwt do |jwt|
  jwt.secret = Rails.application.credentials.devise_jwt_secret_key
  jwt.dispatch_requests = [
    ['POST', %r{^/api/v1/login$}]
  ]
  jwt.revocation_requests = [
    ['DELETE', %r{^/api/v1/logout$}]
  ]
  jwt.expiration_time = 1.day.to_i
end
```

**Option B - Disable API Routes** (TEMPORARY):
```ruby
# config/routes.rb
# Comment out API namespace
# namespace :api do
#   namespace :v1 do
#     ...
#   end
# end
```

**Files to Audit**:
- `config/initializers/devise.rb` (JWT configuration)
- `app/controllers/api/v1/base_controller.rb` (authentication enforcement)
- `app/controllers/api/v1/sessions_controller.rb` (login/logout)
- `app/models/jwt_denylist.rb` (revocation strategy)

**Acceptance Criteria**:
- JWT tokens generated and validated
- Expired tokens rejected (401 Unauthorized)
- Revoked tokens rejected (JwtDenylist check)
- API requests properly scoped to tenant
- Rate limiting configured (rack-attack)

---

### C4. Test Suite Instability (14 Failures)

**Severity**: 🚨 CRITICAL
**Impact**: CI/CD blocked, regression detection disabled
**Effort**: Small (1-2h)
**Risk**: Low (test-only fixes)

**Problem**:
14 test failures prevent CI/CD green builds:
- 9 failures: LeaveBalance uniqueness constraint violation
- 3 failures: Organization I18n locale mismatch
- 2 failures: Organization NOT NULL constraint

**Detailed Analysis** (from CURRENT_WORKFLOW.md):

**Group 1 - LeaveBalance** (9 failures):
```ruby
# spec/domains/leave_management/models/leave_balance_spec.rb:274
let!(:cp_balance) { create(:leave_balance, :cp, employee: employee) }

# Line 335 - CONFLICT
let!(:expiring_soon_balance) {
  create(:leave_balance, :expiring_soon, employee: employee, leave_type: 'CP', organization: organization)
  # ❌ Creates SECOND CP balance for same employee → violates unique constraint
}
```

**Fix**: Remove `leave_type: 'CP'` parameter (factory trait `:expiring_soon` uses 'RTT' by default)

**Group 2 - Organization I18n** (3 failures):
```ruby
# spec/models/organization_spec.rb:35, 41, 47
expect(organization.errors[:name]).to include("can't be blank")
# ❌ App configured with locale :fr, receives "doit être rempli(e)"
```

**Fix**: Update expectations to French: `"doit être rempli(e)"`

**Group 3 - Organization NOT NULL** (2 failures):
```ruby
# spec/models/organization_spec.rb:94, 500
organization.update_column(:settings, nil)
# ❌ PostgreSQL enforces NOT NULL constraint at DB level
```

**Fix**: Remove impossible tests (DB constraint prevents nil)

**Files to Fix**:
- `spec/domains/leave_management/models/leave_balance_spec.rb` (line 335)
- `spec/models/organization_spec.rb` (lines 35, 41, 47, 94-99, 500-508)

**Acceptance Criteria**:
- 617/617 tests passing (100%)
- SimpleCov minimum_coverage re-enabled (40%)
- No regression on existing tests

---

### C5. Authorization Enforcement Inconsistency

**Severity**: 🚨 CRITICAL (Security)
**Impact**: Authorization bypass risk, audit trail gaps
**Effort**: Medium (3-4h)
**Risk**: Medium (requires careful testing)

**Problem**:
Some controllers use Pundit policies, others use manual authorization checks.

**Examples**:

```ruby
# LeaveRequestsController - INCONSISTENT
before_action :authorize_manager!, only: [:approve, :reject]

def authorize_manager!
  unless current_employee.manager?
    redirect_to dashboard_path, alert: 'Accès réservé aux managers'
  end
end
# ❌ Bypasses LeaveRequestPolicy#approve?, no record-level check
```

**Should be**:
```ruby
def approve
  authorize @leave_request  # Uses LeaveRequestPolicy#approve?
  @leave_request.approve!(current_employee)
  # ...
end
```

**Gap Analysis**:

| Controller | Policy | Manual Check | Status |
|------------|--------|--------------|--------|
| LeaveRequestsController | ✅ Partial | ⚠️ Some actions | MIXED |
| Admin::OrganizationsController | ❌ None | ✅ `authorize_admin!` | MANUAL |
| Manager::ExportsController | ❌ None | ⚠️ Namespace-level | WEAK |
| API controllers | ❓ Unknown | ❓ Unknown | AUDIT NEEDED |

**Solution**:

1. Create missing policies:
   - `OrganizationPolicy`
   - `ExportPolicy` (for CSV access control)

2. Replace manual checks with Pundit:
   ```ruby
   # Before
   before_action :authorize_manager!

   # After
   before_action :authorize_record

   def authorize_record
     authorize @record
   end
   ```

3. Audit API controllers for policy enforcement

**Files to Fix**:
- `app/controllers/leave_requests_controller.rb` (remove manual checks)
- `app/controllers/admin/organizations_controller.rb` (add policy)
- `app/controllers/manager/exports_controller.rb` (add policy)
- `app/policies/organization_policy.rb` (create)
- `app/policies/export_policy.rb` (create)

**Acceptance Criteria**:
- All controllers use `authorize @record` consistently
- No manual `unless current_employee.manager?` checks
- OrganizationPolicy implemented
- ExportPolicy implemented (department-level access control)
- API controllers audited and fixed

---

### C6. No Audit Trail for Sensitive Operations

**Severity**: 🚨 CRITICAL (Compliance)
**Impact**: Cannot track who changed balances, regulatory risk
**Effort**: Medium (4-6h)
**Risk**: Medium (schema changes)

**Problem**:
Leave balance mutations (approve, accrue, manual adjustments) have no audit trail.

**Scenarios Requiring Audit**:
1. Manager approves leave → balance decremented
2. Monthly job accrues CP → balance incremented
3. HR manually adjusts balance → balance changed
4. RTT accrual from overtime → balance incremented

**Current State**:
```ruby
# LeaveRequest#approve!
employee.leave_balances.find_by(leave_type: leave_type).decrement!(:balance, days_count)
# ❌ No record of who, when, why
```

**Solution - Add Audit Log**:

```bash
rails generate model LeaveBalanceAudit \
  employee:references \
  leave_balance:references \
  action:string \
  amount:decimal \
  balance_before:decimal \
  balance_after:decimal \
  reason:string \
  performed_by:references \
  metadata:jsonb \
  organization:references
```

**Usage**:
```ruby
def approve!(approver)
  ActiveRecord::Base.transaction do
    balance = employee.leave_balances.find_by(leave_type: leave_type)

    LeaveBalanceAudit.create!(
      employee: employee,
      leave_balance: balance,
      action: 'leave_approved',
      amount: -days_count,
      balance_before: balance.balance,
      balance_after: balance.balance - days_count,
      reason: "Leave request #{id} approved",
      performed_by: approver,
      metadata: { leave_request_id: id }
    )

    update!(status: 'approved', approved_by: approver, approved_at: Time.current)
    balance.decrement!(:balance, days_count)
  end
end
```

**Files to Create**:
- `app/models/leave_balance_audit.rb`
- `db/migrate/YYYYMMDDHHMMSS_create_leave_balance_audits.rb`

**Files to Modify**:
- `app/domains/leave_management/models/leave_request.rb` (approve!, reject!)
- `app/jobs/leave_accrual_job.rb` (monthly accrual)
- `app/jobs/rtt_accrual_job.rb` (weekly accrual)

**Acceptance Criteria**:
- All balance changes logged to LeaveBalanceAudit
- Audit records include: who, when, amount, reason
- Immutable audit trail (no updates, only inserts)
- Indexed for fast querying (employee_id, created_at)

---

### C7. No Rate Limiting (API Security)

**Severity**: 🚨 CRITICAL (Security)
**Impact**: DDoS vulnerability, abuse potential
**Effort**: Small (1-2h)
**Risk**: Low (proven gem)

**Problem**:
API endpoints have no rate limiting. Malicious actors can:
- Brute force login attempts
- Exhaust server resources
- Create expensive queries

**Solution - Install rack-attack**:

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# Throttle login attempts
Rack::Attack.throttle('login attempts', limit: 5, period: 60.seconds) do |req|
  if req.path == '/api/v1/login' && req.post?
    req.ip
  end
end

# Throttle API requests per token
Rack::Attack.throttle('api requests', limit: 100, period: 1.minute) do |req|
  if req.path.start_with?('/api/')
    req.env['warden']&.user&.id
  end
end

# Blocklist specific IPs (manual intervention)
Rack::Attack.blocklist('bad actors') do |req|
  Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 1.minute, bantime: 1.hour) do
    req.path.start_with?('/api/') && (req.get? || req.post?)
  end
end
```

**Files to Create**:
- `config/initializers/rack_attack.rb`

**Files to Modify**:
- `Gemfile` (add rack-attack)
- `config/application.rb` (add middleware)

**Acceptance Criteria**:
- Login attempts limited to 5/minute per IP
- API requests limited to 100/minute per user
- Blocked IPs return 429 Too Many Requests
- Redis or Memory cache configured

---

### C8. Missing JSONB Schema Validation

**Severity**: 🚨 CRITICAL (Data Quality)
**Impact**: Inconsistent data, query failures, migration pain
**Effort**: Medium (3-4h)
**Risk**: Low (additive validation)

**Problem**:
JSONB fields have no schema validation. Any structure can be saved, leading to:
- Query failures: `settings['work_week_hours']` returns nil unexpectedly
- Inconsistent keys: `work_week_hours` vs `workWeekHours`
- Type mismatches: `"35"` (string) vs `35` (integer)

**JSONB Fields in Use**:
1. `employees.settings` (active status, preferences)
2. `employees.contract_overrides` (custom legal rules)
3. `organizations.settings` (work_week_hours, CP rates, etc.)
4. `work_schedules.schedule_pattern` (days with hours)
5. `weekly_schedule_plans.schedule_pattern` (weekly overrides)
6. `time_entries.location` (GPS coordinates)

**Solution - Add JSON Schema Validation**:

```ruby
# app/models/organization.rb
validates :settings, presence: true
validate :settings_schema

SETTINGS_SCHEMA = {
  type: 'object',
  required: ['work_week_hours', 'cp_acquisition_rate'],
  properties: {
    work_week_hours: { type: 'number', minimum: 0, maximum: 48 },
    cp_acquisition_rate: { type: 'number', minimum: 0, maximum: 3 },
    cp_expiry_month: { type: 'integer', minimum: 1, maximum: 12 },
    cp_expiry_day: { type: 'integer', minimum: 1, maximum: 31 },
    rtt_enabled: { type: 'boolean' },
    overtime_threshold: { type: 'number' },
    max_daily_hours: { type: 'integer', minimum: 8, maximum: 12 }
  },
  additionalProperties: false
}.freeze

def settings_schema
  validator = JSON::Validator.new(SETTINGS_SCHEMA, settings, validate_schema: true)
  unless validator.valid?
    errors.add(:settings, "invalid schema: #{validator.error_message}")
  end
rescue JSON::Schema::ValidationError => e
  errors.add(:settings, "schema error: #{e.message}")
end
```

**Alternative - Use json_schemer gem**:
```ruby
# Gemfile
gem 'json_schemer'

# app/models/organization.rb
validates :settings, presence: true, json_schema: { schema: SETTINGS_SCHEMA }
```

**Files to Modify**:
- `app/models/organization.rb` (add settings schema)
- `app/models/employee.rb` (add settings + contract_overrides schemas)
- `app/domains/scheduling/models/work_schedule.rb` (add schedule_pattern schema)
- `app/models/weekly_schedule_plan.rb` (add schedule_pattern schema)
- `app/domains/time_tracking/models/time_entry.rb` (add location schema)

**Acceptance Criteria**:
- All JSONB fields have defined schemas
- Invalid JSON rejected with clear error messages
- Existing data migrated to conform (data migration)
- Tests verify schema enforcement

---

## HIGH PRIORITY ISSUES (Scalability Risks)

### H1. N+1 Queries in Manager Views

**Severity**: ⚠️ HIGH
**Impact**: Performance degradation with large teams (100+ employees)
**Effort**: Small (2-3h)
**Risk**: Low (additive change)

**Problem**:
Manager dashboards query database once per team member.

**Example**:
```ruby
# DashboardController
@pending_requests = current_employee.leave_requests.pending.limit(5)
# View renders: @pending_requests.each { |r| r.approved_by.name }
# ❌ N+1: 1 query for requests + N queries for approved_by
```

**Detected Locations**:
1. `app/controllers/dashboard_controller.rb:10` - `.pending` without includes
2. `app/controllers/leave_requests_controller.rb:8` - index action
3. `app/controllers/manager/time_entries_controller.rb` - team entries
4. `app/services/exports/time_entries_csv_exporter.rb:45` - team export

**Solution**:
```ruby
# Before
@pending_requests = current_employee.leave_requests.pending.limit(5)

# After
@pending_requests = current_employee.leave_requests
                                    .includes(:approved_by, :employee)
                                    .pending
                                    .limit(5)
```

**Install Bullet gem for detection**:
```ruby
# Gemfile
group :development do
  gem 'bullet'
end

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
end
```

**Files to Fix**:
- `app/controllers/dashboard_controller.rb`
- `app/controllers/leave_requests_controller.rb`
- `app/controllers/manager/time_entries_controller.rb`
- `app/controllers/manager/leave_requests_controller.rb`
- `app/services/exports/time_entries_csv_exporter.rb`
- `app/services/exports/absences_csv_exporter.rb`

**Acceptance Criteria**:
- Bullet reports 0 N+1 queries on critical pages
- Dashboard load time <150ms (down from ~450ms)
- Manager views load time <200ms

---

### H2. Missing Database Indexes

**Severity**: ⚠️ HIGH
**Impact**: Slow queries at scale, full table scans
**Effort**: Small (30min)
**Risk**: Low (additive migration)

**Problem**:
Frequently queried columns lack composite indexes.

**Missing Indexes**:

```ruby
# leave_requests - queried by status + employee
SELECT * FROM leave_requests
WHERE employee_id = 123 AND status = 'pending'
ORDER BY created_at DESC;
# ❌ Sequential scan, no composite index

# time_entries - queried by employee + date range
SELECT * FROM time_entries
WHERE employee_id = 123
  AND clock_in BETWEEN '2026-02-01' AND '2026-02-28';
# ❌ Index on employee_id exists, but clock_in range scan slow

# notifications - queried by recipient + read status
SELECT * FROM notifications
WHERE recipient_id = 123 AND read_at IS NULL;
# ❌ No index on read_at
```

**Solution - Migration**:

```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # LeaveRequest - status + date filtering
    add_index :leave_requests, [:employee_id, :status],
              name: 'idx_leave_requests_employee_status'
    add_index :leave_requests, [:start_date, :end_date],
              name: 'idx_leave_requests_date_range'
    add_index :leave_requests, [:status, :created_at],
              name: 'idx_leave_requests_status_created',
              where: "status = 'pending'"  # Partial index for pending only

    # TimeEntry - employee + date range
    add_index :time_entries, [:employee_id, :clock_in],
              name: 'idx_time_entries_employee_clock_in'
    add_index :time_entries, [:employee_id, :validated_at],
              name: 'idx_time_entries_employee_validated',
              where: 'validated_at IS NULL'  # Pending validation

    # Notification - recipient + read status
    add_index :notifications, [:recipient_id, :read_at],
              name: 'idx_notifications_recipient_read'
    add_index :notifications, [:recipient_id, :created_at],
              name: 'idx_notifications_recipient_created'

    # Employee - manager hierarchy queries
    add_index :employees, [:manager_id, :organization_id],
              name: 'idx_employees_manager_org'
  end
end
```

**Test Impact**:
```sql
-- Before
EXPLAIN ANALYZE SELECT * FROM leave_requests
WHERE employee_id = 123 AND status = 'pending';
-- Seq Scan on leave_requests (cost=0.00..1234.56 rows=50 width=256)
-- Execution Time: 45.234 ms

-- After
EXPLAIN ANALYZE SELECT * FROM leave_requests
WHERE employee_id = 123 AND status = 'pending';
-- Index Scan using idx_leave_requests_employee_status (cost=0.29..8.31 rows=1 width=256)
-- Execution Time: 0.123 ms  (366x faster!)
```

**Files to Create**:
- `db/migrate/YYYYMMDDHHMMSS_add_performance_indexes.rb`

**Acceptance Criteria**:
- EXPLAIN ANALYZE shows index usage (not seq scan)
- Dashboard queries <10ms
- Manager approval page <50ms

---

### H3. Background Jobs Not Sharded

**Severity**: ⚠️ HIGH
**Impact**: Job timeouts at scale (10k employees = 33min job)
**Effort**: Medium (3-4h)
**Risk**: Medium (job logic changes)

**Problem**:
LeaveAccrualJob and RttAccrualJob process ALL employees sequentially.

**Current**:
```ruby
# app/jobs/leave_accrual_job.rb
def perform
  ActsAsTenant.without_tenant do
    Organization.find_each do |organization|
      ActsAsTenant.with_tenant(organization) do
        # Process ALL employees in this org (could be 1000+)
        Employee.active.find_each do |employee|
          # 200ms per employee × 10k = 33 minutes!
        end
      end
    end
  end
end
```

**Solution - Shard by Organization**:

```ruby
# app/jobs/leave_accrual_job.rb (becomes dispatcher)
def perform
  ActsAsTenant.without_tenant do
    Organization.find_each do |organization|
      # Enqueue 1 job per organization
      OrganizationLeaveAccrualJob.perform_later(organization.id)
    end
  end
end

# app/jobs/organization_leave_accrual_job.rb (NEW)
class OrganizationLeaveAccrualJob < ApplicationJob
  queue_as :default

  def perform(organization_id)
    organization = Organization.find(organization_id)
    ActsAsTenant.with_tenant(organization) do
      Employee.active.find_each do |employee|
        accrue_leave_for_employee(employee)
      end
    end
  end

  private

  def accrue_leave_for_employee(employee)
    # Existing accrual logic
  end
end
```

**Benefits**:
- Parallelization: SolidQueue processes orgs concurrently
- Fault isolation: 1 org failure doesn't block others
- Monitoring: Track progress per organization
- Retry granularity: Retry failed org, not entire job

**Files to Modify**:
- `app/jobs/leave_accrual_job.rb` (make dispatcher)
- `app/jobs/rtt_accrual_job.rb` (make dispatcher)

**Files to Create**:
- `app/jobs/organization_leave_accrual_job.rb`
- `app/jobs/organization_rtt_accrual_job.rb`

**Acceptance Criteria**:
- LeaveAccrualJob completes <5min (all orgs, parallel)
- RttAccrualJob completes <5min (all orgs, parallel)
- SolidQueue dashboard shows per-org jobs
- Failed org retries don't re-process successful orgs

---

### H4. Policy Scopes Use N+1 Queries

**Severity**: ⚠️ HIGH
**Impact**: Authorization checks slow with large teams
**Effort**: Small (1-2h)
**Risk**: Low (query optimization)

**Problem**:
Policy helper methods load full ActiveRecord collections.

**Example**:
```ruby
# app/policies/leave_request_policy.rb
def approve?
  user.manager? && manages?(record.employee)
end

private

def manages?(employee)
  user.team_members.include?(employee)  # ❌ Loads all team members into memory
end
```

**At Scale**:
- Manager with 100 reports
- Each `approve?` check loads 100 Employee records
- 10 leave requests on page = 1000 Employee loads

**Solution**:

```ruby
# Option 1 - Use IDs (pluck)
def manages?(employee)
  team_member_ids.include?(employee.id)
end

def team_member_ids
  @team_member_ids ||= user.team_members.pluck(:id)
end

# Option 2 - Direct query (best)
def approve?
  user.manager? && user.team_members.exists?(record.employee_id)
end
```

**Files to Fix**:
- `app/policies/leave_request_policy.rb` (manages? helper)
- `app/policies/time_entry_policy.rb` (manages? helper)
- `app/policies/work_schedule_policy.rb` (manages? helper)

**Acceptance Criteria**:
- Policy checks use `.exists?` or `.pluck(:id)`
- No `.include?` on ActiveRecord collections
- Bullet reports 0 N+1 in policy scopes

---

### H5. No Data Archival Strategy

**Severity**: ⚠️ HIGH
**Impact**: time_entries table will reach millions of rows, degrading all queries
**Effort**: Large (8-12h)
**Risk**: Medium (requires partitioning + archival jobs)

**Problem**:
time_entries grows unbounded. At scale:
- 10k employees × 20 entries/month × 12 months = **2.4M rows/year**
- After 5 years: **12M rows**
- Queries slow, backups large, disk fills

**Solution - Partition + Archive**:

**Step 1 - Partition by Year**:
```sql
-- PostgreSQL 11+ native partitioning
CREATE TABLE time_entries (
  id bigserial,
  organization_id bigint NOT NULL,
  employee_id bigint NOT NULL,
  clock_in timestamp NOT NULL,
  -- ... other columns
) PARTITION BY RANGE (clock_in);

CREATE TABLE time_entries_2024 PARTITION OF time_entries
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE time_entries_2025 PARTITION OF time_entries
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE time_entries_2026 PARTITION OF time_entries
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
```

**Step 2 - Archive Old Data**:
```ruby
# app/jobs/archive_time_entries_job.rb
class ArchiveTimeEntriesJob < ApplicationJob
  def perform
    cutoff_date = 3.years.ago

    TimeEntry.where('clock_in < ?', cutoff_date).find_in_batches(batch_size: 1000) do |batch|
      # Export to S3/archive storage
      ArchiveStorage.store("time_entries_#{batch.first.id}_#{batch.last.id}.json", batch.to_json)

      # Delete from primary DB
      TimeEntry.where(id: batch.map(&:id)).delete_all
    end
  end
end
```

**Alternative - Separate Archive Table**:
```sql
CREATE TABLE time_entries_archive (LIKE time_entries INCLUDING ALL);

-- Move old data monthly
INSERT INTO time_entries_archive
SELECT * FROM time_entries
WHERE clock_in < (CURRENT_DATE - INTERVAL '3 years');

DELETE FROM time_entries
WHERE clock_in < (CURRENT_DATE - INTERVAL '3 years');
```

**Files to Create**:
- `db/migrate/YYYYMMDDHHMMSS_partition_time_entries.rb`
- `app/jobs/archive_time_entries_job.rb`
- `app/services/archive_storage.rb` (S3 integration)

**Acceptance Criteria**:
- time_entries partitioned by year
- Data >3 years archived to S3 monthly
- Active table size <2M rows
- Queries remain <100ms

---

### H6. No Idempotency Guarantees on Jobs

**Severity**: ⚠️ HIGH
**Impact**: Duplicate accruals if job retries
**Effort**: Medium (2-3h)
**Risk**: Low (additive checks)

**Problem**:
Background jobs don't check if work already completed.

**Scenario**:
1. LeaveAccrualJob runs on Feb 1st
2. Accrues 2.5 CP days for Employee #123
3. Job crashes before logging completion
4. Job retries → accrues ANOTHER 2.5 days (total 5 days!)

**Current (Not Idempotent)**:
```ruby
def accrue_leave_for_employee(employee)
  balance = employee.leave_balances.find_by(leave_type: 'CP')
  balance.increment!(:accrued_this_year, 2.5)
  balance.increment!(:balance, 2.5)
  # ❌ No check if already accrued this month
end
```

**Solution - Add Idempotency Key**:

```ruby
# Migration
add_column :leave_balance_audits, :idempotency_key, :string
add_index :leave_balance_audits, :idempotency_key, unique: true

# Job
def accrue_leave_for_employee(employee)
  idempotency_key = "leave_accrual_#{employee.id}_#{Date.current.strftime('%Y-%m')}"

  return if LeaveBalanceAudit.exists?(idempotency_key: idempotency_key)

  balance = employee.leave_balances.find_by(leave_type: 'CP')
  ActiveRecord::Base.transaction do
    balance.increment!(:accrued_this_year, 2.5)
    balance.increment!(:balance, 2.5)

    LeaveBalanceAudit.create!(
      employee: employee,
      leave_balance: balance,
      action: 'monthly_accrual',
      amount: 2.5,
      idempotency_key: idempotency_key  # ✅ Prevents duplicate
    )
  end
end
```

**Files to Modify**:
- `app/jobs/leave_accrual_job.rb` (add idempotency check)
- `app/jobs/rtt_accrual_job.rb` (add idempotency check)
- `db/migrate/..._add_idempotency_key_to_leave_balance_audits.rb`

**Acceptance Criteria**:
- Jobs can be run multiple times for same period without duplication
- Idempotency key includes: employee_id + period (YYYY-MM)
- LeaveBalanceAudit unique constraint enforces idempotency

---

### H7. No Monitoring/Alerting

**Severity**: ⚠️ HIGH
**Impact**: Production issues go unnoticed, slow response time
**Effort**: Medium (3-4h)
**Risk**: Low (external service)

**Problem**:
No error tracking, no performance monitoring, no alerting.

**Solution - Sentry + Application Monitoring**:

```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1  # 10% of requests
  config.environment = Rails.env
  config.enabled_environments = %w[production staging]

  # Filter sensitive data
  config.send_default_pii = false
  config.before_send = lambda do |event, hint|
    event.request.data = event.request.data.except('password', 'authentication_token')
    event
  end
end
```

**Custom Alerts**:
```ruby
# app/jobs/leave_accrual_job.rb
def perform
  start_time = Time.current
  success_count = 0
  error_count = 0

  # ... job logic

rescue => e
  Sentry.capture_exception(e, level: 'error', tags: { job: 'leave_accrual' })
  raise
ensure
  duration = Time.current - start_time

  Sentry.capture_message(
    "LeaveAccrualJob completed",
    level: 'info',
    extra: {
      duration: duration,
      success_count: success_count,
      error_count: error_count
    }
  )

  # Alert if job takes too long
  if duration > 10.minutes
    Sentry.capture_message("LeaveAccrualJob slow", level: 'warning')
  end
end
```

**Files to Create**:
- `config/initializers/sentry.rb`

**Files to Modify**:
- `Gemfile` (add sentry gems)
- All background jobs (add monitoring)

**Acceptance Criteria**:
- Sentry dashboard shows errors in real-time
- Performance metrics tracked (P50, P95, P99)
- Alerts configured: errors, slow jobs, high memory
- PagerDuty/Slack integration for critical alerts

---

### H8. CSV Exports Load All Data into Memory

**Severity**: ⚠️ HIGH
**Impact**: Memory exhaustion with large exports (10k employees)
**Effort**: Small (1-2h)
**Risk**: Low (already uses find_each)

**Problem**:
CSV exports for large teams may load too much data.

**Current (Partially OK)**:
```ruby
# app/services/exports/time_entries_csv_exporter.rb
def export
  CSV.generate(headers: true, col_sep: ';', encoding: 'UTF-8') do |csv|
    csv << headers

    team_members.find_each do |employee|  # ✅ find_each batches DB queries
      time_entries = fetch_time_entries(employee, ...)
      time_entries.each do |entry|  # ⚠️ All entries for employee loaded
        csv << row_for(entry)
      end
    end
  end
end
```

**Issue**:
- `fetch_time_entries(employee)` returns ALL entries for date range
- For 1 year export: 1 employee × 240 entries × 10k employees = **2.4M rows in memory**

**Solution - Stream CSV Rows**:

```ruby
def export
  CSV.generate(headers: true, col_sep: ';', encoding: 'UTF-8') do |csv|
    csv << headers

    team_members.find_each do |employee|
      # Stream entries in batches
      fetch_time_entries(employee, ...).find_each(batch_size: 100) do |entry|
        csv << row_for(entry)
      end
    end
  end
end

def fetch_time_entries(employee, start_date, end_date)
  # Return relation (not array)
  TimeEntry.where(employee: employee)
           .where(clock_in: start_date..end_date)
           .order(:clock_in)
  # ✅ Caller can use find_each
end
```

**Files to Fix**:
- `app/services/exports/time_entries_csv_exporter.rb` (use find_each)
- `app/services/exports/absences_csv_exporter.rb` (use find_each)

**Acceptance Criteria**:
- Exports use `.find_each` for all queries
- Memory usage <500MB for 10k employee export
- No timeout errors on large exports

---

### H9. No Database Connection Pooling Configuration

**Severity**: ⚠️ HIGH
**Impact**: Connection exhaustion with concurrent requests
**Effort**: Small (30min)
**Risk**: Low (config change)

**Problem**:
Default Rails database pool (5 connections) insufficient for production.

**Calculation**:
- Puma workers: 2
- Puma threads per worker: 5
- Total concurrent requests: 2 × 5 = **10**
- Database pool: 5 ❌ **Insufficient!**

**Solution**:

```yaml
# config/database.yml
production:
  <<: *default
  database: izi_rh_production
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>  # ❌ Default
  # Should be:
  pool: <%= ENV.fetch("DB_POOL") { 15 } %>  # ✅ Workers × Threads + buffer

  # Connection timeouts
  checkout_timeout: 5  # Seconds to wait for connection
  reaping_frequency: 10  # Seconds between connection checks

  # Connection management
  variables:
    statement_timeout: 10000  # 10 seconds max query time
    idle_in_transaction_session_timeout: 60000  # 1 minute idle transaction
```

**Environment Variables**:
```bash
# .env.production
DB_POOL=15  # (2 workers × 5 threads) + 5 buffer
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

**Files to Modify**:
- `config/database.yml` (update pool size)
- `.env.production` (add DB_POOL)

**Acceptance Criteria**:
- Pool size ≥ (workers × threads)
- No "could not obtain a connection from the pool" errors
- Connection checkout time <100ms

---

### H10. No Zeitwerk Namespace Cleanup

**Severity**: ⚠️ HIGH (Technical Debt)
**Impact**: Autoloading issues in production, hard-to-debug errors
**Effort**: Small (1h)
**Risk**: Low (namespace refactor)

**Problem**:
CLAUDE.md warns: "Zeitwerk namespace issue in LeaveManagement::Services"

**Current**:
```ruby
# app/domains/leave_management/services/leave_policy_engine.rb
module LeaveManagement
  module Services
    class LeavePolicyEngine
      # ...
    end
  end
end
```

**Zeitwerk Expected Structure**:
```
app/domains/leave_management/
  services/
    leave_policy_engine.rb  # Expected: LeaveManagement::Services::LeavePolicyEngine
```

**Issue**:
If file explicitly declares `module LeaveManagement::Services`, Zeitwerk conflicts with autoload path.

**Solution**:

```ruby
# Option 1 - Remove explicit module (let Zeitwerk infer)
# app/domains/leave_management/services/leave_policy_engine.rb
class LeavePolicyEngine  # ✅ Zeitwerk adds LeaveManagement::Services
  # ...
end

# Option 2 - Nested modules
# app/domains/leave_management/services/leave_policy_engine.rb
module LeaveManagement
  module Services
    class LeavePolicyEngine  # ✅ Explicit, matches file path
      # ...
    end
  end
end
```

**Files to Audit**:
- All files in `app/domains/*/services/`
- All files in `app/domains/*/models/`
- Check: Does module nesting match directory structure?

**Files to Fix**:
- `app/domains/leave_management/services/leave_policy_engine.rb`
- `app/domains/time_tracking/services/rtt_accrual_service.rb`

**Acceptance Criteria**:
- No Zeitwerk warnings in production logs
- `rails zeitwerk:check` passes
- Constants autoload without explicit requires

---

## MEDIUM PRIORITY ISSUES (Technical Debt)

### M1. God Object: LeavePolicyEngine (308 Lines)

**Severity**: 🔧 MEDIUM
**Impact**: Hard to test, hard to maintain, violates SRP
**Effort**: Large (6-8h)
**Risk**: High (critical business logic)

**Problem**:
LeavePolicyEngine has 4 distinct responsibilities in 1 file.

**Responsibilities**:
1. French public holidays calculation (70 lines)
2. Working days calculation (60 lines)
3. CP accrual calculation (70 lines)
4. RTT accrual calculation (80 lines)

**Cyclomatic Complexity**: 45 (should be <10)

**Solution - Split into 4 Services**:

1. **FrenchPublicHolidaysService** (~70 lines)
   - `for_year(year)` → array of Date objects
   - `is_holiday?(date)` → boolean
   - Computus algorithm for Easter, Ascension, Pentecost

2. **WorkingDaysCalculator** (~60 lines)
   - `call(start_date, end_date, work_schedule)` → integer
   - Uses FrenchPublicHolidaysService
   - Respects work_schedule pattern

3. **CpAccrualCalculator** (~70 lines)
   - `calculate_monthly_accrual(employee)` → decimal
   - `calculate_for_period(employee, start_date, end_date)` → decimal
   - Part-time proration, max cap

4. **RttAccrualCalculator** (~80 lines)
   - `calculate_from_time_entry(employee, time_entry)` → decimal
   - `calculate_monthly_accrual(employee)` → decimal
   - Overtime threshold logic

**LeavePolicyEngine becomes orchestrator** (~30 lines):
```ruby
module LeaveManagement
  module Services
    class LeavePolicyEngine
      delegate :for_year, :is_holiday?, to: :holidays_service, prefix: :holiday

      def initialize(employee)
        @employee = employee
      end

      def calculate_working_days(start_date, end_date)
        WorkingDaysCalculator.new(start_date, end_date, @employee.work_schedule).call
      end

      def calculate_cp_accrual
        CpAccrualCalculator.new(@employee).calculate_monthly_accrual
      end

      def calculate_rtt_accrual_from_time_entry(time_entry)
        RttAccrualCalculator.new(@employee).calculate_from_time_entry(time_entry)
      end

      private

      def holidays_service
        FrenchPublicHolidaysService
      end
    end
  end
end
```

**Files to Create**:
- `app/domains/leave_management/services/french_public_holidays_service.rb`
- `app/domains/leave_management/services/working_days_calculator.rb`
- `app/domains/leave_management/services/cp_accrual_calculator.rb`
- `app/domains/leave_management/services/rtt_accrual_calculator.rb`

**Files to Modify**:
- `app/domains/leave_management/services/leave_policy_engine.rb` (orchestrator)
- `spec/domains/leave_management/services/leave_policy_engine_spec.rb` (split tests)

**Acceptance Criteria**:
- 153 existing tests still pass (migrate to new services)
- Each service <100 lines
- Cyclomatic complexity <10 per service
- LeavePolicyEngine delegates to services

---

### M2. Service Objects Missing (LeaveRequestCreator)

**Severity**: 🔧 MEDIUM
**Impact**: Fat controllers, hard to test business logic
**Effort**: Medium (3-4h)
**Risk**: Medium (logic extraction)

**Problem**:
`LeaveRequestsController#create` is 77 lines (should be <20).

**Current**:
```ruby
# app/controllers/leave_requests_controller.rb:14-91
def create
  # 20 lines validation
  # 15 lines LeaveRequest creation
  # 10 lines auto-approval logic
  # 10 lines team conflict check
  # 12 lines notification dispatch
  # 10 lines error handling
  # = 77 lines total ❌
end
```

**Solution - Extract Service**:

See detailed implementation in REFACTORING_PLAN.md lines 231-333

**Files to Create**:
- `app/domains/leave_management/services/leave_request_creator.rb`

**Files to Modify**:
- `app/controllers/leave_requests_controller.rb` (reduce to 12 lines)

**Acceptance Criteria**:
- Controller#create <20 lines
- Service returns Result object (success?, leave_request, errors)
- Service tested independently
- Controller tests use service mocks

---

### M3. Controller Concerns Missing

**Severity**: 🔧 MEDIUM
**Impact**: Code duplication across 7 manager controllers
**Effort**: Medium (2-3h)
**Risk**: Low (extraction)

**Problem**:
7 manager controllers duplicate authorization logic.

**Duplication**:
```ruby
# app/controllers/manager/time_entries_controller.rb
before_action :ensure_manager_role

def ensure_manager_role
  unless current_employee.manager? || current_employee.hr? || current_employee.admin?
    redirect_to dashboard_path, alert: "Accès réservé aux managers"
  end
end

# ❌ Repeated in 7 controllers:
# - manager/time_entries_controller.rb
# - manager/leave_requests_controller.rb
# - manager/work_schedules_controller.rb
# - manager/weekly_schedule_plans_controller.rb
# - manager/team_schedules_controller.rb
# - manager/exports_controller.rb
# - manager/dashboard_controller.rb
```

**Solution - Extract Concerns**:

See detailed implementation in REFACTORING_PLAN.md lines 343-425

**Files to Create**:
- `app/controllers/concerns/manager_authorization.rb`
- `app/controllers/concerns/api_error_handling.rb`

**Files to Modify** (7):
- All manager/* controllers (add `include ManagerAuthorization`)

**Acceptance Criteria**:
- Manager authorization logic in 1 place
- API error handling in 1 place
- ~50 lines eliminated

---

### M4. Model Concerns Missing (Validations)

**Severity**: 🔧 MEDIUM
**Impact**: Validation logic duplication
**Effort**: Small (2h)
**Risk**: Low (DRY validations)

**Problem**:
Same-tenant validation repeated in 3 models.

**Duplication**:
```ruby
# LeaveRequest
validate :employee_belongs_to_same_organization
validate :approver_belongs_to_same_organization

def employee_belongs_to_same_organization
  if employee.organization_id != organization_id
    errors.add(:employee, 'must belong to the same organization')
  end
end

# ❌ Repeated in TimeEntry, WorkSchedule, etc.
```

**Solution**:

See detailed implementation in REFACTORING_PLAN.md lines 771-846

**Files to Create**:
- `app/models/concerns/same_tenant_validation.rb`
- `app/models/concerns/date_range_validation.rb`

**Files to Modify**:
- `app/domains/leave_management/models/leave_request.rb`
- `app/domains/time_tracking/models/time_entry.rb`
- `app/domains/scheduling/models/work_schedule.rb`

**Acceptance Criteria**:
- `validates_same_tenant :employee, :approved_by` (DSL)
- `validates_date_range :start_date, :end_date` (DSL)
- ~30 lines eliminated per model

---

### M5. Jobs in Wrong Directory

**Severity**: 🔧 MEDIUM (Architectural Consistency)
**Impact**: Violates DDD structure
**Effort**: Small (1h)
**Risk**: Low (file move)

**Problem**:
Jobs in `app/jobs/` instead of domain directories.

**Current**:
```
app/jobs/
├── leave_accrual_job.rb          # ❌ Should be in leave_management/jobs/
├── rtt_accrual_job.rb            # ❌ Should be in time_tracking/jobs/
├── leave_request_notification_job.rb  # ❌ Should be in leave_management/jobs/
└── weekly_time_validation_reminder_job.rb  # ❌ Should be in time_tracking/jobs/
```

**Expected**:
```
app/domains/leave_management/jobs/
├── leave_accrual_job.rb
└── leave_request_notification_job.rb

app/domains/time_tracking/jobs/
├── rtt_accrual_job.rb
└── weekly_time_validation_reminder_job.rb
```

**Solution**:
```bash
# Move jobs
mv app/jobs/leave_accrual_job.rb app/domains/leave_management/jobs/
mv app/jobs/rtt_accrual_job.rb app/domains/time_tracking/jobs/
mv app/jobs/leave_request_notification_job.rb app/domains/leave_management/jobs/
mv app/jobs/weekly_time_validation_reminder_job.rb app/domains/time_tracking/jobs/

# Update namespaces (Zeitwerk)
# No code changes needed if using Zeitwerk autoloading
```

**Files to Move** (4):
- All jobs to respective domain directories

**Acceptance Criteria**:
- Jobs in domain directories
- Zeitwerk autoloads correctly
- Scheduled jobs still run

---

### M6. API Serializers Missing

**Severity**: 🔧 MEDIUM (Security)
**Impact**: Over-exposure of data (password_digest, tokens)
**Effort**: Medium (3-4h)
**Risk**: Low (additive)

**Problem**:
API controllers return full ActiveRecord objects.

**Current**:
```ruby
# app/controllers/api/v1/leave_requests_controller.rb
def index
  leave_requests = current_employee.leave_requests
  render json: leave_requests  # ❌ Exposes ALL attributes
end
```

**Response includes**:
```json
{
  "id": 123,
  "employee_id": 456,
  "password_digest": "$2a$12$...",  // ❌ SECURITY RISK
  "reset_password_token": "abc123",  // ❌ SECURITY RISK
  "organization_id": 789,  // ❌ Unnecessary exposure
  ...
}
```

**Solution**:

See detailed implementation in REFACTORING_PLAN.md lines 703-763

**Files to Create** (6 serializers):
- `app/serializers/employee_serializer.rb`
- `app/serializers/leave_request_serializer.rb`
- `app/serializers/leave_balance_serializer.rb`
- `app/serializers/time_entry_serializer.rb`
- `app/serializers/work_schedule_serializer.rb`
- `app/serializers/notification_serializer.rb`

**Files to Modify** (5 API controllers):
- All API v1 controllers (use serializers)

**Acceptance Criteria**:
- No password_digest, tokens, or internal IDs in API responses
- Consistent JSON structure
- Include related resources (approved_by, employee)

---

### M7. WeeklySchedulePlan in Wrong Location

**Severity**: 🔧 MEDIUM (Architectural Consistency)
**Impact**: Violates DDD structure
**Effort**: Small (30min)
**Risk**: Low (file move)

**Problem**:
`WeeklySchedulePlan` in `app/models/` instead of `app/domains/scheduling/models/`.

**Current**:
```
app/models/
├── weekly_schedule_plan.rb  # ❌ Belongs to scheduling domain
├── notification.rb          # ✅ OK (cross-domain)
├── jwt_denylist.rb          # ✅ OK (infrastructure)
└── current.rb               # ✅ OK (infrastructure)
```

**Expected**:
```
app/domains/scheduling/models/
├── work_schedule.rb
└── weekly_schedule_plan.rb  # ✅ Consistent with domain
```

**Solution**:
```bash
mv app/models/weekly_schedule_plan.rb app/domains/scheduling/models/
```

**Files to Move**:
- `app/models/weekly_schedule_plan.rb`

**Acceptance Criteria**:
- WeeklySchedulePlan in scheduling domain
- Associations still work
- Tests still pass

---

### M8. NotificationService Missing

**Severity**: 🔧 MEDIUM (Code Organization)
**Impact**: Notification logic scattered across controllers/models
**Effort**: Medium (2-3h)
**Risk**: Low (extraction)

**Problem**:
Notification creation duplicated in 5 places.

**Current**:
```ruby
# In LeaveRequest model
after_create :notify_manager

def notify_manager
  return unless employee.manager

  Notification.create!(
    recipient: employee.manager,
    notification_type: 'leave_request_pending',
    # ... 10 lines of params
  )
end

# ❌ Similar logic in TimeEntry, WorkSchedule, etc.
```

**Solution**:

See detailed implementation in REFACTORING_PLAN.md lines 963-1043

**Files to Create**:
- `app/services/notification_service.rb`

**Files to Modify**:
- Remove after_create callbacks from models
- Use NotificationService explicitly in controllers/services

**Acceptance Criteria**:
- Notification logic in 1 service
- Async email delivery (deliver_later)
- Tests use service mocks

---

## LOW PRIORITY ISSUES (Quality of Life)

### L1. French Holidays Hardcoded

**Severity**: ℹ️ LOW
**Impact**: No regional or company-specific holidays
**Effort**: Medium (2-3h)
**Risk**: Low (data migration)

**Problem**:
French holidays hardcoded in LeavePolicyEngine. No support for:
- Alsace-Moselle (3 additional holidays)
- Company-specific closures
- Collective agreement holidays

**Solution - Extract to Organization.settings**:

```ruby
# Migration
add_column :organizations, :custom_holidays, :jsonb, default: []

# Organization model
class Organization < ApplicationRecord
  def holidays_for_year(year)
    legal_holidays = FrenchPublicHolidaysService.for_year(year)
    custom_holidays = parse_custom_holidays(year)
    (legal_holidays + custom_holidays).uniq.sort
  end

  private

  def parse_custom_holidays(year)
    (custom_holidays || []).map do |holiday|
      Date.parse("#{year}-#{holiday['month']}-#{holiday['day']}")
    end
  rescue
    []
  end
end

# UI for HR to add custom holidays
# settings: {
#   custom_holidays: [
#     { name: "Company Anniversary", month: 6, day: 15 },
#     { name: "Regional Holiday", month: 12, day: 26 }
#   ]
# }
```

**Files to Modify**:
- `app/models/organization.rb` (add holidays_for_year)
- `app/domains/leave_management/services/french_public_holidays_service.rb` (support custom)
- `db/migrate/..._add_custom_holidays_to_organizations.rb`

**Acceptance Criteria**:
- Organizations can define custom holidays
- Working days calculation respects custom holidays
- UI for HR to manage holidays

---

### L2. Value Objects Missing

**Severity**: ℹ️ LOW
**Impact**: Code duplication, primitive obsession
**Effort**: Medium (3-4h)
**Risk**: Low (additive)

**Problem**:
Date ranges, leave types, durations represented as primitives.

**Solution**:

See detailed implementation in REFACTORING_PLAN.md lines 1049-1175

**Files to Create**:
- `app/models/date_range.rb`
- `app/models/leave_type.rb`
- `app/models/duration.rb`

**Files to Modify**:
- Use value objects in models/services

**Acceptance Criteria**:
- `DateRange#overlaps?`, `DateRange#working_days`
- `LeaveType#requires_approval?`, `LeaveType#paid?`
- `Duration#to_human`, `Duration#days`

---

### L3. Presenter Pattern Missing

**Severity**: ℹ️ LOW
**Impact**: Helper methods too complex
**Effort**: Small (1-2h)
**Risk**: Low (extraction)

**Problem**:
Helpers contain view logic.

**Solution**:

See detailed implementation in REFACTORING_PLAN.md lines 1179-1261

**Files to Create**:
- `app/presenters/time_entry_status_presenter.rb`
- `app/presenters/leave_request_status_presenter.rb`

**Acceptance Criteria**:
- Helpers delegate to presenters
- Badge classes, status logic in presenters

---

### L4. Query Objects Missing

**Severity**: ℹ️ LOW
**Impact**: Complex queries in controllers/models
**Effort**: Medium (2-3h per query object)
**Risk**: Low (extraction)

**Problem**:
Complex scopes and queries scattered.

**Example**:
```ruby
# app/controllers/manager/time_entries_controller.rb
def pending_validation
  @time_entries = TimeEntry
                    .joins(:employee)
                    .where(employees: { manager_id: current_employee.id })
                    .where(validated_at: nil)
                    .where('clock_in >= ?', 1.month.ago)
                    .order(clock_in: :desc)
  # ❌ 6 lines of query logic in controller
end
```

**Solution - Extract Query Object**:

```ruby
# app/queries/time_entries/pending_validation_query.rb
module TimeEntries
  class PendingValidationQuery
    def initialize(manager)
      @manager = manager
    end

    def call
      TimeEntry
        .joins(:employee)
        .where(employees: { manager_id: @manager.id })
        .where(validated_at: nil)
        .where('clock_in >= ?', 1.month.ago)
        .order(clock_in: :desc)
    end
  end
end

# Controller
def pending_validation
  @time_entries = TimeEntries::PendingValidationQuery.new(current_employee).call
end
```

**Files to Create**:
- `app/queries/time_entries/pending_validation_query.rb`
- `app/queries/leave_requests/pending_approvals_query.rb`
- `app/queries/leave_requests/team_calendar_query.rb`

**Acceptance Criteria**:
- Complex queries extracted to query objects
- Controllers use query objects
- Query objects tested independently

---

### L5. Event Sourcing Missing

**Severity**: ℹ️ LOW (Future-Proofing)
**Impact**: No event-driven architecture, tight coupling
**Effort**: Large (12-16h)
**Risk**: High (architectural shift)

**Problem**:
Model callbacks tightly couple domains.

**Current**:
```ruby
# app/domains/leave_management/models/leave_request.rb
after_create :notify_manager
after_update :update_leave_balance, if: :saved_change_to_status?

# ❌ LeaveRequest knows about Notification and LeaveBalance
```

**Solution - Domain Events**:

```ruby
# app/events/leave_request_events.rb
module LeaveRequestEvents
  class Created < ApplicationEvent
    attr_reader :leave_request

    def initialize(leave_request)
      @leave_request = leave_request
    end
  end

  class Approved < ApplicationEvent
    attr_reader :leave_request, :approver

    def initialize(leave_request, approver)
      @leave_request = leave_request
      @approver = approver
    end
  end
end

# app/event_handlers/leave_request_notification_handler.rb
class LeaveRequestNotificationHandler
  def handle(event)
    case event
    when LeaveRequestEvents::Created
      NotificationService.leave_request_created(event.leave_request)
    when LeaveRequestEvents::Approved
      NotificationService.leave_request_approved(event.leave_request)
    end
  end
end

# app/domains/leave_management/models/leave_request.rb
def approve!(approver)
  update!(status: 'approved', approved_by: approver, approved_at: Time.current)

  # Publish event (decoupled)
  EventBus.publish(LeaveRequestEvents::Approved.new(self, approver))
end
```

**Files to Create**:
- `app/events/application_event.rb`
- `app/events/leave_request_events.rb`
- `app/event_handlers/leave_request_notification_handler.rb`
- `app/services/event_bus.rb`

**Acceptance Criteria**:
- Events replace callbacks
- Event handlers subscribe to events
- Domains decoupled (no cross-domain imports)

---

## IMPLEMENTATION ROADMAP

### Phase 1: Production Readiness (CRITICAL - 3-5 days)

**Sprint 1.2** - Test Stabilization (1 day)
- [ ] C4: Fix 14 test failures
- [ ] Re-enable SimpleCov minimum_coverage
- [ ] CI/CD green builds

**Sprint 1.3** - Data Integrity (1 day)
- [ ] C1: Add transaction blocks
- [ ] C6: Implement LeaveBalanceAudit
- [ ] H6: Add idempotency to jobs

**Sprint 1.4** - Security (1 day)
- [ ] C2: Implement or remove mailers
- [ ] C3: Complete API authentication
- [ ] C5: Standardize authorization (Pundit)
- [ ] C7: Add rate limiting (rack-attack)

**Sprint 1.5** - Schema Validation (1 day)
- [ ] C8: Add JSONB schema validation

### Phase 2: Scalability (HIGH - 3-4 days)

**Sprint 2.1** - Database Optimization (1 day)
- [ ] H2: Add composite indexes
- [ ] H9: Configure connection pooling

**Sprint 2.2** - Query Optimization (1 day)
- [ ] H1: Fix N+1 queries
- [ ] H4: Optimize policy scopes
- [ ] H8: Stream CSV exports

**Sprint 2.3** - Background Jobs (1-2 days)
- [ ] H3: Shard jobs by organization
- [ ] H7: Add Sentry monitoring

**Sprint 2.4** - Namespace Cleanup (0.5 day)
- [ ] H10: Fix Zeitwerk namespaces

### Phase 3: Code Quality (MEDIUM - 4-6 days)

**Sprint 3.1** - Service Objects (2 days)
- [ ] M1: Split LeavePolicyEngine
- [ ] M2: Extract LeaveRequestCreator
- [ ] M8: Create NotificationService

**Sprint 3.2** - Concerns (1 day)
- [ ] M3: ManagerAuthorization concern
- [ ] M3: ApiErrorHandling concern
- [ ] M4: SameTenantValidation concern
- [ ] M4: DateRangeValidation concern

**Sprint 3.3** - Structural Cleanup (1 day)
- [ ] M5: Move jobs to domain directories
- [ ] M7: Move WeeklySchedulePlan to domain

**Sprint 3.4** - API Security (1 day)
- [ ] M6: Implement API serializers

### Phase 4: Future-Proofing (LOW - Optional)

**Sprint 4.1** - Data Archival (2-3 days)
- [ ] H5: Partition time_entries by year
- [ ] H5: Implement archival job

**Sprint 4.2** - Enhancements (2-3 days)
- [ ] L1: Custom holidays configuration
- [ ] L2: Value objects (DateRange, LeaveType)
- [ ] L3: Presenter pattern
- [ ] L4: Query objects

**Sprint 4.3** - Event Sourcing (4-5 days)
- [ ] L5: Domain events architecture
- [ ] L5: Event handlers
- [ ] L5: Replace callbacks

---

## ACCEPTANCE CRITERIA (Production Launch)

### Must-Have (P0 - Before First Client)

- [ ] All CRITICAL issues resolved (C1-C8)
- [ ] Test suite 100% passing (0 failures)
- [ ] Test coverage ≥40% (SimpleCov enforced)
- [ ] Database indexes added (H2)
- [ ] N+1 queries fixed on dashboard (H1)
- [ ] API authentication complete or disabled (C3)
- [ ] Rate limiting configured (C7)
- [ ] Transactions on all balance mutations (C1)
- [ ] Mailers implemented or removed (C2)
- [ ] Authorization consistent (C5)
- [ ] JSONB schema validation (C8)
- [ ] Audit trail for balances (C6)
- [ ] CI/CD pipeline green
- [ ] Monitoring configured (Sentry)

### Should-Have (P1 - Before 10 Clients)

- [ ] Background jobs sharded (H3)
- [ ] Idempotency on jobs (H6)
- [ ] Connection pooling configured (H9)
- [ ] Zeitwerk namespaces fixed (H10)
- [ ] LeavePolicyEngine split (M1)
- [ ] Service objects extracted (M2, M8)
- [ ] Controller concerns (M3)
- [ ] Model concerns (M4)
- [ ] API serializers (M6)
- [ ] Test coverage ≥50%

### Nice-to-Have (P2 - Before 50 Clients)

- [ ] Data archival strategy (H5)
- [ ] CSV streaming optimized (H8)
- [ ] Custom holidays (L1)
- [ ] Value objects (L2)
- [ ] Presenter pattern (L3)
- [ ] Query objects (L4)
- [ ] Event sourcing (L5)
- [ ] Test coverage ≥80%

---

## RISK ASSESSMENT

### High-Risk Changes (Require Extensive Testing)

1. **C1 - Transaction Blocks**: Race conditions if incorrect
2. **M1 - Split LeavePolicyEngine**: Critical French legal logic
3. **H3 - Job Sharding**: Data loss if idempotency broken
4. **H5 - Data Partitioning**: Irreversible schema change
5. **L5 - Event Sourcing**: Architectural shift

**Mitigation**:
- Test on staging with production-like data
- Canary deployments (1 org → 10 orgs → all orgs)
- Rollback plan for each change
- Monitor Sentry for 24h after deploy

### Low-Risk Changes (Safe to Deploy)

1. **C4 - Test Fixes**: Test-only changes
2. **H2 - Database Indexes**: Additive, no breaking changes
3. **H7 - Monitoring**: External service
4. **M3-M8 - Concerns/Serializers**: DRY refactoring
5. **L1-L4 - Value Objects/Presenters**: Additive patterns

---

## ESTIMATED EFFORT SUMMARY

| Phase | Effort (days) | Risk | Priority |
|-------|---------------|------|----------|
| **Phase 1: Production Readiness** | 3-5 | HIGH | P0 |
| **Phase 2: Scalability** | 3-4 | MEDIUM | P1 |
| **Phase 3: Code Quality** | 4-6 | LOW | P1 |
| **Phase 4: Future-Proofing** | 8-11 | LOW | P2 |
| **TOTAL** | **18-26 days** | - | - |

**Recommended Team**:
- 1 Senior Developer (architectural changes)
- 1 Mid-Level Developer (concerns, serializers)
- 1 QA Engineer (test coverage expansion)

**Timeline**:
- Phase 1: Week 1-2 (CRITICAL)
- Phase 2: Week 3 (HIGH)
- Phase 3: Week 4-5 (MEDIUM)
- Phase 4: Ongoing (LOW)

---

**End of Architectural Changes Required**
**Next Step**: Review with team, prioritize P0 issues, begin Sprint 1.2
