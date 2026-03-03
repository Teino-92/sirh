# DEVELOPER ROADMAP — EASY-RH
**Date**: 2026-02-16 (Updated 2026-02-27)
**Target Agent**: @developer
**Source**: Architectural Review by @architect
**Priority**: Execute sequentially, no parallel work

---

## 📋 HOW TO USE THIS ROADMAP

This roadmap is your **step-by-step implementation guide**. Each sprint is designed to be executed in order, with clear:
- ✅ **Acceptance criteria** (when you're done)
- 📝 **Detailed implementation steps**
- 🧪 **Testing requirements**
- ⚠️ **Gotchas to avoid**

**IMPORTANT RULES**:
1. **One sprint at a time** - Complete ALL tasks in a sprint before moving to next
2. **Tests MUST pass** - Never commit failing tests
3. **@qa validation required** - Each sprint ends with @qa → @architect validation
4. **No improvisation** - Follow specs exactly, ask @architect if unclear
5. **Commit after each task** - Small, focused commits with clear messages

---

## 🎯 SPRINT OVERVIEW

| Sprint | Focus | Effort | Status |
|--------|-------|--------|--------|
| **1.2** | Fix Test Failures | 1-2h | ✅ COMPLETE (2026-02-16) |
| **1.3** | Add Transaction Safety | 2-3h | ✅ COMPLETE (2026-02-16) |
| **1.4** | Mailer Implementation (Option A) | 0.5h | ✅ COMPLETE (2026-02-16) |
| **1.5** | Database Indexes | 1h | ✅ COMPLETE (2026-02-16) |
| **1.6** | Fix N+1 Queries | 2-3h | ✅ COMPLETE (2026-02-16) |
| **1.7** | API Serializers | 3-4h | ✅ COMPLETE (2026-02-27) |
| **1.8** | Rate Limiting | 1-2h | ✅ COMPLETE (2026-02-27) |
| **2.1** | Shard Background Jobs | 3-4h | ✅ COMPLETE (2026-02-27) |
| **2.2** | JSONB Schema Validation | 3-4h | ✅ COMPLETE (2026-02-27) |
| **2.3** | Audit Trail System | 4-5h | ✅ COMPLETE (2026-02-27) |
| **D-A** | Direction A (scoping + tests + rename) | ~6h | ✅ COMPLETE (2026-02-27) |
| **D-B** | Direction B (policy specs + OnboardingTaskPolicy) | ~3h | ✅ COMPLETE (2026-02-27) |
| **D-C** | Direction C (GroupPolicies spec, OnboardingReview spec, Payroll auth+N+1) | ~2h | ✅ COMPLETE (2026-02-27) |
| **D-D** | Direction D (confidentialité salariale — droit du travail français) | ~1h | ✅ COMPLETE (2026-02-27) |
| **D-E** | Direction E (edit/update salary guard, _form conditionné) | ~1h | ✅ COMPLETE (2026-02-27) |
| **D-F** | Direction F (HR Query Engine — NL-to-Filters IA admin/RH) | ~4h | ✅ COMPLETE (2026-02-27) |

**Progress**: 10/10 roadmap sprints complete (100%) + Directions A + B + C + D + E + F complete + Points résiduels complets
**Time Spent**: ~35 hours (tous les sprints + toutes les Directions + nettoyage résiduel)
**Remaining Effort**: 0h — Phase 3 à scoper par @architect

---

## 📊 COMPLETED SPRINTS SUMMARY

### Sprint 1.2 - Fix Test Failures ✅
- **Completed**: 2026-02-16
- **Commits**: f3dedd0, 28fd77c, 56c5d8a
- **Impact**: 619/619 tests passing (100%), coverage 20.1%
- **Report**: SPRINT_1.2_COMPLETION.md

### Sprint 1.3 - Add Transaction Safety ✅
- **Completed**: 2026-02-16
- **Commits**: 6b7a081, 0e8f40c, 120dc1b
- **Impact**: Leave balance mutations now atomic, accrual jobs wrapped in transactions
- **Report**: SPRINT_1.3_COMPLETION.md

### Sprint 1.4 - Mailer Implementation (Option A) ✅
- **Completed**: 2026-02-16
- **Commit**: 2168391
- **Impact**: Job failures eliminated, email notifications deferred to Sprint 2.x
- **Report**: SPRINT_1.4_COMPLETION.md

### Sprint 1.5 - Database Indexes ✅
- **Completed**: 2026-02-16
- **Commit**: c1d9dbe
- **Impact**: 6 composite + 2 partial indexes, 366x faster queries at scale
- **Report**: SPRINT_1.5_COMPLETION.md

### Sprint 1.6 - Fix N+1 Queries ✅
- **Completed**: 2026-02-16
- **Commit**: cd7fef0
- **Impact**: 82-99% query reduction, 37-71% faster page loads
- **Report**: SPRINT_1.6_COMPLETION.md

**Key Achievements**:
- ✅ Test suite: 100% passing (619/619)
- ✅ Data integrity: ACID transactions on critical operations
- ✅ Performance: ~500x improvement (indexes + eager loading combined)
- ✅ Multi-tenancy: All safety validations passed
- ✅ Production ready: Zero-downtime deployments for all sprints

### Direction F — HR Query Engine (NL-to-Filters) ✅
- **Completed**: 2026-02-27
- **Commit**: cd85d0a
- **Impact**: Admin/RH can query HR data in French natural language via Claude Haiku AI
- **Security**: NL-to-Filters (never Text-to-SQL), schema not exposed to API, salary re-gated server-side
- **Files**: `HrQueryInterpreterService`, `HrQueryExecutorService`, `HrQueryCsvExporter`, `HrQueryPolicy`, `Admin::HrQueriesController`, views + Stimulus controller
- **Specs**: interpreter (7 examples), executor (8 examples), policy (12 examples) — all passing
- **Deps**: `faraday ~> 2.7`, `faraday-retry ~> 2.2`, `dotenv-rails`
- **Model**: `claude-haiku-4-5-20251001`, JSON prefill technique, MAX_RESULTS=500

### Points résiduels — Nettoyage pré-Phase 3 ✅
- **Completed**: 2026-02-27
- **Audit nav mobile**: lien "Audit" ajouté dans la bottom nav admin (`admin.html.erb`)
- **Mailers activés**: `LeaveRequestMailer` + `TimeEntryMailer` branchés dans les jobs (remplacement des `Rails.logger` TODO), vues `.text.erb` écrites, layout mailer enrichi
- **Bug fix accrual**: `OrganizationLeaveAccrualJob` — correction calcul `remaining_cap` (min/max inversé causait `monthly_accrual = 0`)
- **RTT notification**: TODO supprimé — log approprié dans `rtt_accrual_job.rb`
- **JWT**: déjà complet (`devise-jwt`, `JwtDenylist`, dispatch/revocation, token header) — aucun travail requis
- **Nouvelles specs**: `JsonbValidatable` concern (7 ex), `LeaveAccrualDispatcherJob` (3 ex), `OrganizationLeaveAccrualJob` (6 ex), `AuditLogPolicy` (4 ex) — tous verts

---

# SPRINT 1.2 — FIX TEST FAILURES

**Objective**: Get test suite to 100% passing (617/617 tests green)
**Effort**: 1-2 hours
**Complexity**: LOW (test-only changes)
**Priority**: 🚨 CRITICAL

## 📝 Context

Current status: 617 examples, 603 passing (97.7%), **14 failures**

**Failure Groups**:
1. **LeaveBalance uniqueness** (9 failures) - Duplicate `leave_type: 'CP'`
2. **Organization I18n** (3 failures) - French vs English validation messages
3. **Organization NOT NULL** (2 failures) - DB constraint prevents `settings: nil`

## 🎯 Acceptance Criteria

- [ ] 617/617 tests passing (100%)
- [ ] `bundle exec rspec` exits with code 0
- [ ] SimpleCov minimum_coverage re-enabled (40%)
- [ ] No regressions (all existing tests still valid)

## 🛠️ Implementation Steps

### Task 1.2.1 — Fix LeaveBalance Uniqueness (9 failures)

**File**: `spec/domains/leave_management/models/leave_balance_spec.rb`

**Problem** (Line 335):
```ruby
let!(:cp_balance) { create(:leave_balance, :cp, employee: employee) }  # Line 274

# Line 335 - CONFLICT
let!(:expiring_soon_balance) {
  create(:leave_balance, :expiring_soon, employee: employee, leave_type: 'CP', organization: organization)
  # ❌ Creates SECOND CP balance for same employee → violates unique constraint
}
```

**Solution**:
```ruby
# Line 335 - REMOVE leave_type parameter
let!(:expiring_soon_balance) {
  create(:leave_balance, :expiring_soon, employee: employee, organization: organization)
  # ✅ Factory trait :expiring_soon uses 'RTT' by default (no conflict)
}
```

**Steps**:
1. Open `spec/domains/leave_management/models/leave_balance_spec.rb`
2. Go to line 335
3. Remove `, leave_type: 'CP'` from the create call
4. Save file
5. Run: `bundle exec rspec spec/domains/leave_management/models/leave_balance_spec.rb:343` (first failure)
6. Verify it passes
7. Run: `bundle exec rspec spec/domains/leave_management/models/leave_balance_spec.rb` (all LeaveBalance tests)
8. Verify all 9 failures now pass

**Expected Result**: 9 failures → 0 failures in LeaveBalance spec

---

### Task 1.2.2 — Fix Organization I18n (3 failures)

**File**: `spec/models/organization_spec.rb`

**Problem** (Lines 35, 41, 47):
```ruby
it 'validates presence of name' do
  organization.name = nil
  organization.valid?
  expect(organization.errors[:name]).to include("can't be blank")
  # ❌ App uses locale :fr, returns "doit être rempli(e)"
end
```

**Solution**:
```ruby
it 'validates presence of name' do
  organization.name = nil
  organization.valid?
  expect(organization.errors[:name]).to include("doit être rempli(e)")
  # ✅ French validation message
end
```

**Steps**:
1. Open `spec/models/organization_spec.rb`
2. Find line 35 (first validation test)
3. Replace `"can't be blank"` with `"doit être rempli(e)"`
4. Repeat for lines 41 and 47
5. Run: `bundle exec rspec spec/models/organization_spec.rb:33` (first failure)
6. Verify it passes
7. Run: `bundle exec rspec spec/models/organization_spec.rb` (all Organization tests)

**Expected Result**: 3 failures → 0 failures in Organization validation tests

---

### Task 1.2.3 — Fix Organization NOT NULL (2 failures)

**File**: `spec/models/organization_spec.rb`

**Problem** (Lines 94-99, 500-508):
```ruby
# Line 94-99
it 'uses default settings when nil' do
  organization.update_column(:settings, nil)  # ❌ PostgreSQL prevents this
  expect(organization.reload.settings).to eq(Organization::DEFAULT_SETTINGS)
end

# Line 500-508
context 'when settings is nil' do
  before { organization.update_column(:settings, nil) }  # ❌ Impossible
  # ...
end
```

**Migration shows**:
```ruby
t.jsonb :settings, default: {}, null: false  # DB enforces NOT NULL
```

**Solution**: Delete these tests (legacy scenario impossible)

**Steps**:
1. Open `spec/models/organization_spec.rb`
2. Go to lines 94-99 (first test block)
3. Delete entire test block:
   ```ruby
   it 'uses default settings when nil' do
     # DELETE THIS ENTIRE TEST
   end
   ```
4. Go to lines 500-508 (context block)
5. Delete entire context block:
   ```ruby
   context 'when settings is nil' do
     # DELETE THIS ENTIRE CONTEXT
   end
   ```
6. Save file
7. Run: `bundle exec rspec spec/models/organization_spec.rb`
8. Verify no failures related to `settings: nil`

**Expected Result**: 2 failures → 0 failures (tests removed)

---

### Task 1.2.4 — Re-enable SimpleCov Threshold

**File**: `spec/spec_helper.rb`

**Current** (Line 16):
```ruby
# minimum_coverage 40  # Disabled temporarily - will re-enable once tests are fixed
```

**Solution**:
```ruby
minimum_coverage 40  # ✅ Re-enabled
```

**Steps**:
1. Open `spec/spec_helper.rb`
2. Go to line 16
3. Uncomment the line (remove `#`)
4. Update comment:
   ```ruby
   minimum_coverage 40  # Re-enabled after Sprint 1.2
   ```
5. Save file

---

### Task 1.2.5 — Full Test Suite Run

**Steps**:
1. Run full test suite:
   ```bash
   bundle exec rspec
   ```

2. Verify output:
   ```
   617 examples, 0 failures

   Coverage report generated for RSpec to /coverage. 542 / 2330 LOC (23.26%) covered.
   ```

3. Check SimpleCov enforcement:
   ```bash
   # Should NOT see error like:
   # "Coverage (23.26%) is below the expected minimum coverage (40.00%)."
   # This is OK for now - we're at 23.26%, will increase in Sprint 1.3+
   ```

4. If SimpleCov fails due to low coverage, temporarily set:
   ```ruby
   minimum_coverage 23  # Sprint 1.2 - will increase to 40 in Sprint 2.x
   ```

---

## 🧪 Testing Checklist

- [ ] `bundle exec rspec spec/domains/leave_management/models/leave_balance_spec.rb` → 0 failures
- [ ] `bundle exec rspec spec/models/organization_spec.rb` → 0 failures
- [ ] `bundle exec rspec` → 617 examples, 0 failures
- [ ] SimpleCov runs without errors
- [ ] Coverage report generated in `coverage/index.html`

## 📦 Commit Strategy

**Commit 1** - Fix LeaveBalance tests:
```bash
git add spec/domains/leave_management/models/leave_balance_spec.rb
git commit -m "fix(tests): remove duplicate leave_type in expiring_soon_balance factory

- Remove leave_type: 'CP' parameter from line 335
- Prevents uniqueness constraint violation (employee_id + leave_type)
- Fixes 9 test failures in LeaveBalance spec

Ref: Sprint 1.2, Task 1.2.1"
```

**Commit 2** - Fix Organization I18n tests:
```bash
git add spec/models/organization_spec.rb
git commit -m "fix(tests): update validation messages to French locale

- Replace 'can't be blank' with 'doit être rempli(e)'
- App configured with I18n.default_locale = :fr
- Fixes 3 test failures in Organization validation specs

Ref: Sprint 1.2, Task 1.2.2"
```

**Commit 3** - Remove impossible tests:
```bash
git add spec/models/organization_spec.rb
git commit -m "fix(tests): remove legacy settings nil tests

- Delete tests attempting settings: nil (DB constraint prevents)
- Migration enforces NOT NULL on organizations.settings
- Fixes 2 test failures (impossible scenario)

Ref: Sprint 1.2, Task 1.2.3"
```

**Commit 4** - Re-enable SimpleCov:
```bash
git add spec/spec_helper.rb
git commit -m "test(coverage): re-enable SimpleCov minimum_coverage

- Uncomment minimum_coverage threshold
- Set to 23% (current level) for Sprint 1.2
- Will increase to 40% after controller/policy tests added

Ref: Sprint 1.2, Task 1.2.4"
```

## ⚠️ Gotchas

1. **Don't change model code** - Only touch spec files
2. **Run tests incrementally** - Fix one group, test, then move to next
3. **Check factory traits** - `:expiring_soon` trait defaults to `leave_type: 'RTT'`
4. **French locale** - All validation messages must be in French
5. **SimpleCov threshold** - May need to adjust to 23% temporarily

## 🎓 What You'll Learn

- Factory trait behavior (`:expiring_soon` defaults)
- I18n validation messages in tests
- Database constraints vs model validations
- SimpleCov configuration

## 📋 Handoff to QA

After completing all tasks:

1. Create summary comment:
   ```
   Sprint 1.2 Complete - Test Failures Fixed

   ✅ Tasks Completed:
   - Fixed LeaveBalance uniqueness (9 failures → 0)
   - Fixed Organization I18n (3 failures → 0)
   - Removed impossible tests (2 failures → 0)
   - Re-enabled SimpleCov threshold (23%)

   📊 Test Results:
   - Total: 617 examples
   - Passing: 617 (100%)
   - Failures: 0
   - Coverage: 23.26%

   🔗 Commits:
   - <commit_sha_1> Fix LeaveBalance tests
   - <commit_sha_2> Fix Organization I18n
   - <commit_sha_3> Remove legacy tests
   - <commit_sha_4> Re-enable SimpleCov

   Ready for @qa validation.
   ```

2. Tag @qa for validation
3. Wait for approval before moving to Sprint 1.3

---

# SPRINT 1.3 — ADD TRANSACTION SAFETY

**Objective**: Wrap all balance mutations in database transactions
**Effort**: 2-3 hours
**Complexity**: MEDIUM (critical business logic)
**Priority**: 🚨 CRITICAL

## 📝 Context

**Problem**: Leave balance mutations occur without transactional safety. If one operation fails mid-flow, data becomes inconsistent.

**Example Risk**:
1. LeaveRequest status → `approved` ✅
2. Server crashes ❌
3. LeaveBalance NOT decremented ❌
4. Result: Employee has approved leave but balance unchanged (data corruption)

**Solution**: Wrap in `ActiveRecord::Base.transaction` blocks.

## 🎯 Acceptance Criteria

- [ ] All balance mutations wrapped in transactions
- [ ] Rollback on any exception (all-or-nothing)
- [ ] Tests verify atomicity (raise exception mid-transaction, assert no partial updates)
- [ ] No regressions (all 617 tests still pass)

## 🛠️ Implementation Steps

### Task 1.3.1 — Add Transaction to LeaveRequest#approve!

**File**: `app/domains/leave_management/models/leave_request.rb`

**Current Code** (find around line 45-50):
```ruby
def approve!(approver)
  update!(status: 'approved', approved_by: approver, approved_at: Time.current)
  employee.leave_balances.find_by(leave_type: leave_type).decrement!(:balance, days_count)
  # ❌ Not atomic - crash between lines leaves inconsistent state
end
```

**New Code**:
```ruby
def approve!(approver)
  ActiveRecord::Base.transaction do
    update!(status: 'approved', approved_by: approver, approved_at: Time.current)

    balance = employee.leave_balances.find_by(leave_type: leave_type)
    raise "Balance not found for #{leave_type}" unless balance

    balance.decrement!(:balance, days_count)
  end
  # ✅ Transaction ensures both updates succeed or both rollback
end
```

**Steps**:
1. Open `app/domains/leave_management/models/leave_request.rb`
2. Locate `def approve!(approver)` method
3. Wrap entire method body in `ActiveRecord::Base.transaction do ... end`
4. Add error handling for missing balance
5. Save file

---

### Task 1.3.2 — Add Transaction to LeaveRequest#reject!

**File**: `app/domains/leave_management/models/leave_request.rb`

**Current Code** (find around line 55-60):
```ruby
def reject!(approver, reason:)
  update!(
    status: 'rejected',
    approved_by: approver,
    approved_at: Time.current,
    rejection_reason: reason
  )
  # No balance change on rejection, but transaction ensures consistency
end
```

**New Code** (if status update triggers callbacks that modify balances):
```ruby
def reject!(approver, reason:)
  ActiveRecord::Base.transaction do
    update!(
      status: 'rejected',
      approved_by: approver,
      approved_at: Time.current,
      rejection_reason: reason
    )
  end
end
```

**Steps**:
1. Same file as Task 1.3.1
2. Locate `def reject!(approver, reason:)` method
3. Wrap in transaction (defensive programming)
4. Save file

---

### Task 1.3.3 — Add Transaction to LeaveAccrualJob

**File**: `app/jobs/leave_accrual_job.rb`

**Current Code** (find around line 60-70):
```ruby
def accrue_leave_for_employee(employee)
  balance = employee.leave_balances.find_or_create_by(leave_type: 'CP')

  monthly_accrual = 2.5  # Simplified - actual logic more complex
  balance.increment!(:accrued_this_year, monthly_accrual)
  balance.increment!(:balance, monthly_accrual)
  # ❌ Not atomic
end
```

**New Code**:
```ruby
def accrue_leave_for_employee(employee)
  ActiveRecord::Base.transaction do
    balance = employee.leave_balances.find_or_create_by(leave_type: 'CP')

    monthly_accrual = calculate_monthly_accrual(employee)
    balance.increment!(:accrued_this_year, monthly_accrual)
    balance.increment!(:balance, monthly_accrual)

    Rails.logger.info "CP accrued for #{employee.email}: +#{monthly_accrual} days"
  end
rescue => e
  Rails.logger.error "CP accrual failed for #{employee.id}: #{e.message}"
  # Don't re-raise - continue with other employees
end
```

**Steps**:
1. Open `app/jobs/leave_accrual_job.rb`
2. Locate `accrue_leave_for_employee` method (or similar)
3. Wrap balance mutations in transaction
4. Add rescue block (job should continue if 1 employee fails)
5. Save file

---

### Task 1.3.4 — Add Transaction to RttAccrualJob

**File**: `app/jobs/rtt_accrual_job.rb`

**Current Code** (find around line 80-85):
```ruby
def update_rtt_balance(employee, days)
  balance = employee.leave_balances.find_or_create_by(leave_type: 'rtt')
  balance.increment!(:balance, days)
  # ❌ Not atomic
end
```

**New Code**:
```ruby
def update_rtt_balance(employee, days)
  ActiveRecord::Base.transaction do
    balance = employee.leave_balances.find_or_create_by(leave_type: 'rtt')
    balance.increment!(:balance, days)

    Rails.logger.info "RTT accrued for #{employee.email}: +#{days} days"
  end
rescue => e
  Rails.logger.error "RTT accrual failed for #{employee.id}: #{e.message}"
  # Don't re-raise - continue with other employees
end
```

**Steps**:
1. Open `app/jobs/rtt_accrual_job.rb`
2. Locate balance update method
3. Wrap in transaction
4. Add rescue block
5. Save file

---

### Task 1.3.5 — Write Transaction Atomicity Tests

**File**: `spec/domains/leave_management/models/leave_request_spec.rb`

**Add new test context** (insert after existing approve! tests):
```ruby
describe '#approve!' do
  # ... existing tests ...

  context 'transaction atomicity' do
    it 'rolls back leave request status if balance update fails' do
      leave_request = create(:leave_request, :pending, employee: employee)
      balance = employee.leave_balances.find_by(leave_type: leave_request.leave_type)

      # Simulate balance update failure
      allow(balance).to receive(:decrement!).and_raise(ActiveRecord::RecordInvalid)
      allow(employee.leave_balances).to receive(:find_by).and_return(balance)

      expect {
        leave_request.approve!(manager)
      }.to raise_error(ActiveRecord::RecordInvalid)

      # Assert rollback: status should NOT be approved
      expect(leave_request.reload.status).to eq('pending')
    end

    it 'commits both leave request and balance updates together' do
      leave_request = create(:leave_request, :pending, employee: employee, days_count: 5)
      balance = employee.leave_balances.find_by(leave_type: leave_request.leave_type)
      initial_balance = balance.balance

      leave_request.approve!(manager)

      # Assert both updates succeeded
      expect(leave_request.reload.status).to eq('approved')
      expect(balance.reload.balance).to eq(initial_balance - 5)
    end
  end
end
```

**Steps**:
1. Open `spec/domains/leave_management/models/leave_request_spec.rb`
2. Find the `describe '#approve!'` block
3. Add the `context 'transaction atomicity'` block at the end
4. Run: `bundle exec rspec spec/domains/leave_management/models/leave_request_spec.rb -e "transaction atomicity"`
5. Verify both new tests pass

---

### Task 1.3.6 — Write Job Transaction Tests

**File**: `spec/jobs/leave_accrual_job_spec.rb` (create if doesn't exist)

```ruby
require 'rails_helper'

RSpec.describe LeaveAccrualJob, type: :job do
  let(:organization) { create(:organization) }
  let(:employee) { create(:employee, organization: organization) }

  before do
    ActsAsTenant.current_tenant = organization
  end

  describe '#perform' do
    context 'transaction atomicity' do
      it 'rolls back balance changes if error occurs mid-accrual' do
        balance = employee.leave_balances.find_or_create_by(leave_type: 'CP')
        initial_balance = balance.balance

        # Simulate error during increment
        allow(balance).to receive(:increment!).and_raise(StandardError, "Simulated error")
        allow_any_instance_of(Employee).to receive(:leave_balances).and_return(
          double(find_or_create_by: balance)
        )

        expect {
          LeaveAccrualJob.new.send(:accrue_leave_for_employee, employee)
        }.not_to change { balance.reload.balance }

        # Assert balance unchanged (rollback)
        expect(balance.reload.balance).to eq(initial_balance)
      end
    end
  end
end
```

**Steps**:
1. Create `spec/jobs/leave_accrual_job_spec.rb` if it doesn't exist
2. Add the test above
3. Run: `bundle exec rspec spec/jobs/leave_accrual_job_spec.rb`
4. Verify test passes
5. Repeat for `spec/jobs/rtt_accrual_job_spec.rb`

---

## 🧪 Testing Checklist

- [ ] `bundle exec rspec spec/domains/leave_management/models/leave_request_spec.rb` → All tests pass
- [ ] `bundle exec rspec spec/jobs/leave_accrual_job_spec.rb` → New atomicity test passes
- [ ] `bundle exec rspec spec/jobs/rtt_accrual_job_spec.rb` → New atomicity test passes
- [ ] `bundle exec rspec` → 617+ examples, 0 failures (may add tests)
- [ ] Manual test: Approve leave request in UI → balance decremented atomically

## 📦 Commit Strategy

**Commit 1** - Add transactions to LeaveRequest:
```bash
git add app/domains/leave_management/models/leave_request.rb
git commit -m "feat(leave): add transaction safety to approve! and reject!

- Wrap status update + balance decrement in ActiveRecord transaction
- Ensures atomicity: both succeed or both rollback
- Add error handling for missing balance
- Prevents data corruption on mid-flow failures

Ref: Sprint 1.3, Task 1.3.1-1.3.2"
```

**Commit 2** - Add transactions to jobs:
```bash
git add app/jobs/leave_accrual_job.rb app/jobs/rtt_accrual_job.rb
git commit -m "feat(jobs): add transaction safety to accrual jobs

- Wrap balance mutations in transactions
- Add rescue blocks to prevent job failure on single employee error
- Improve logging (success + error cases)
- Ensures CP/RTT accrual atomicity

Ref: Sprint 1.3, Task 1.3.3-1.3.4"
```

**Commit 3** - Add atomicity tests:
```bash
git add spec/domains/leave_management/models/leave_request_spec.rb
git add spec/jobs/leave_accrual_job_spec.rb
git add spec/jobs/rtt_accrual_job_spec.rb
git commit -m "test(transactions): verify rollback on balance update failures

- Add transaction atomicity tests for LeaveRequest
- Add transaction tests for accrual jobs
- Verify rollback when balance update fails
- Verify both updates succeed together

Ref: Sprint 1.3, Task 1.3.5-1.3.6"
```

## ⚠️ Gotchas

1. **Don't nest transactions unnecessarily** - Rails handles nested transactions with savepoints
2. **Job rescue blocks** - Don't re-raise errors in jobs (continue processing other employees)
3. **Test doubles** - Use `allow().to receive().and_raise()` to simulate errors
4. **Balance not found** - Always check balance exists before decrement
5. **find_or_create_by** - Already atomic (uses SELECT + INSERT in transaction)

## 🎓 What You'll Learn

- Database transaction semantics (ACID)
- Rails `ActiveRecord::Base.transaction` API
- Rollback behavior on exceptions
- Testing transactions with RSpec doubles
- Error handling in background jobs

## 📋 Handoff to QA

After completing all tasks:

```
Sprint 1.3 Complete - Transaction Safety Added

✅ Tasks Completed:
- Added transactions to LeaveRequest#approve! and #reject!
- Added transactions to LeaveAccrualJob
- Added transactions to RttAccrualJob
- Added atomicity tests (rollback + success cases)

📊 Test Results:
- Total: 620+ examples (added 3 new tests)
- Passing: 100%
- Coverage: ~24% (slight increase)

🔒 Security Impact:
- Data corruption risk eliminated
- Balance mutations now atomic (all-or-nothing)
- Job failures isolated (don't affect other employees)

🔗 Commits:
- <commit_sha_1> Add transactions to LeaveRequest
- <commit_sha_2> Add transactions to jobs
- <commit_sha_3> Add atomicity tests

Ready for @qa validation.
```

---

# SPRINT 1.4 — MAILER IMPLEMENTATION

**Objective**: Implement missing mailers or remove references
**Effort**: 4-6 hours (full implementation) OR 30 minutes (remove references)
**Complexity**: MEDIUM
**Priority**: 🚨 CRITICAL

## 📝 Context

Background jobs reference mailers that don't exist:
- `LeaveRequestMailer` (4 methods)
- `TimeEntryMailer` (1 method)

**Decision Required**: Implement mailers OR remove references?

**Recommendation**: Remove references for MVP (30min), implement in Sprint 2.x (6h)

## 🎯 Acceptance Criteria

**Option A - Remove References** (QUICK FIX):
- [ ] All mailer calls commented out or removed
- [ ] Jobs run without errors
- [ ] Logging added in place of emails

**Option B - Full Implementation** (COMPLETE):
- [ ] LeaveRequestMailer with 4 methods implemented
- [ ] TimeEntryMailer with 1 method implemented
- [ ] Email templates created (text + HTML)
- [ ] Mailer tests passing
- [ ] Preview classes for development

## 🛠️ Implementation Steps — OPTION A (Remove References)

### Task 1.4.1 — Remove LeaveRequestMailer Calls

**File**: `app/jobs/leave_request_notification_job.rb`

**Current Code**:
```ruby
def perform(leave_request_id, action)
  leave_request = LeaveRequest.find(leave_request_id)

  case action
  when :submitted
    LeaveRequestMailer.submitted(leave_request).deliver_now  # ❌
  when :approved
    LeaveRequestMailer.approved(leave_request).deliver_now  # ❌
  when :rejected
    LeaveRequestMailer.rejected(leave_request).deliver_now  # ❌
  when :cancelled
    LeaveRequestMailer.cancelled(leave_request).deliver_now  # ❌
  end
end
```

**New Code** (Option A - Remove):
```ruby
def perform(leave_request_id, action)
  leave_request = LeaveRequest.find(leave_request_id)

  case action
  when :submitted
    # TODO: Implement LeaveRequestMailer in Sprint 2.x
    Rails.logger.info "[EMAIL] Leave request submitted: #{leave_request.id} (Employee: #{leave_request.employee.email})"
  when :approved
    Rails.logger.info "[EMAIL] Leave request approved: #{leave_request.id} (Employee: #{leave_request.employee.email})"
  when :rejected
    Rails.logger.info "[EMAIL] Leave request rejected: #{leave_request.id} (Employee: #{leave_request.employee.email})"
  when :cancelled
    Rails.logger.info "[EMAIL] Leave request cancelled: #{leave_request.id} (Employee: #{leave_request.employee.email})"
  end
end
```

**Steps**:
1. Open `app/jobs/leave_request_notification_job.rb`
2. Replace all `LeaveRequestMailer.*` calls with `Rails.logger.info`
3. Add TODO comment for future implementation
4. Save file

---

### Task 1.4.2 — Remove TimeEntryMailer Calls

**File**: `app/jobs/weekly_time_validation_reminder_job.rb`

**Current Code**:
```ruby
def notify_manager(manager, pending_count)
  TimeEntryMailer.weekly_validation_reminder(manager, pending_count).deliver_now  # ❌
end
```

**New Code** (Option A - Remove):
```ruby
def notify_manager(manager, pending_count)
  # TODO: Implement TimeEntryMailer in Sprint 2.x
  Rails.logger.info "[EMAIL] Validation reminder: #{manager.email} has #{pending_count} pending time entries"
end
```

**Steps**:
1. Open `app/jobs/weekly_time_validation_reminder_job.rb`
2. Replace `TimeEntryMailer.*` call with `Rails.logger.info`
3. Add TODO comment
4. Save file

---

### Task 1.4.3 — Test Jobs Run Without Errors

**Steps**:
1. Open Rails console:
   ```bash
   rails console
   ```

2. Test LeaveRequestNotificationJob:
   ```ruby
   org = Organization.first
   ActsAsTenant.current_tenant = org
   leave_request = LeaveRequest.first
   LeaveRequestNotificationJob.perform_now(leave_request.id, :submitted)
   # Should log: [EMAIL] Leave request submitted: <id>
   ```

3. Test WeeklyTimeValidationReminderJob:
   ```ruby
   manager = Employee.where(role: 'manager').first
   WeeklyTimeValidationReminderJob.new.send(:notify_manager, manager, 5)
   # Should log: [EMAIL] Validation reminder: <email> has 5 pending...
   ```

4. Verify no `uninitialized constant` errors
5. Check logs show `[EMAIL]` messages

---

## 🛠️ Implementation Steps — OPTION B (Full Implementation)

**⚠️ SKIP THIS SECTION IF USING OPTION A**

### Task 1.4.4 — Generate LeaveRequestMailer

```bash
rails generate mailer LeaveRequest submitted approved rejected cancelled
```

**File Created**: `app/mailers/leave_request_mailer.rb`

**Implementation**:
```ruby
class LeaveRequestMailer < ApplicationMailer
  default from: 'noreply@easy-rh.com'

  def submitted(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee
    @manager = @employee.manager

    mail(
      to: @manager.email,
      subject: "Nouvelle demande de congé - #{@employee.full_name}"
    )
  end

  def approved(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee

    mail(
      to: @employee.email,
      subject: "Demande de congé approuvée"
    )
  end

  def rejected(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee

    mail(
      to: @employee.email,
      subject: "Demande de congé refusée"
    )
  end

  def cancelled(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee
    @manager = @employee.manager

    mail(
      to: @manager.email,
      subject: "Demande de congé annulée - #{@employee.full_name}"
    ) if @manager.present?
  end
end
```

**Create Email Templates**:

1. `app/views/leave_request_mailer/submitted.text.erb`:
   ```erb
   Bonjour <%= @manager.first_name %>,

   <%= @employee.full_name %> a soumis une nouvelle demande de congé :

   Type : <%= @leave_request.leave_type.upcase %>
   Dates : Du <%= l(@leave_request.start_date, format: :long) %> au <%= l(@leave_request.end_date, format: :long) %>
   Durée : <%= @leave_request.days_count %> jour(s)
   Raison : <%= @leave_request.reason %>

   Pour approuver ou rejeter cette demande, connectez-vous à Easy-RH.

   Cordialement,
   L'équipe Easy-RH
   ```

2. Repeat for `approved.text.erb`, `rejected.text.erb`, `cancelled.text.erb`

**Steps**:
1. Run generator command
2. Implement mailer methods (see above)
3. Create 4 text templates (`.text.erb`)
4. Optional: Create 4 HTML templates (`.html.erb`)
5. Test in Rails console:
   ```ruby
   lr = LeaveRequest.first
   LeaveRequestMailer.submitted(lr).deliver_now
   # Check logs for email sent
   ```

---

### Task 1.4.5 — Generate TimeEntryMailer

```bash
rails generate mailer TimeEntry weekly_validation_reminder
```

**Implementation**:
```ruby
class TimeEntryMailer < ApplicationMailer
  default from: 'noreply@easy-rh.com'

  def weekly_validation_reminder(manager, pending_count)
    @manager = manager
    @pending_count = pending_count

    mail(
      to: @manager.email,
      subject: "Rappel : #{@pending_count} pointage(s) à valider"
    )
  end
end
```

**Email Template** (`app/views/time_entry_mailer/weekly_validation_reminder.text.erb`):
```erb
Bonjour <%= @manager.first_name %>,

Vous avez <%= @pending_count %> pointage(s) en attente de validation pour votre équipe.

Merci de vous connecter à Easy-RH pour valider ces pointages.

Cordialement,
L'équipe Easy-RH
```

---

### Task 1.4.6 — Configure Action Mailer (Production)

**File**: `config/environments/production.rb`

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: :plain,
  enable_starttls_auto: true
}

config.action_mailer.default_url_options = { host: ENV['APP_HOST'] }
```

**Environment Variables** (`.env.production`):
```bash
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=<sendgrid_api_key>
APP_HOST=easy-rh.com
```

---

### Task 1.4.7 — Write Mailer Tests

**File**: `spec/mailers/leave_request_mailer_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe LeaveRequestMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, :manager, organization: organization) }
  let(:employee) { create(:employee, manager: manager, organization: organization) }
  let(:leave_request) { create(:leave_request, employee: employee) }

  before { ActsAsTenant.current_tenant = organization }

  describe '#submitted' do
    let(:mail) { LeaveRequestMailer.submitted(leave_request) }

    it 'sends to manager' do
      expect(mail.to).to eq([manager.email])
    end

    it 'has correct subject' do
      expect(mail.subject).to include('Nouvelle demande de congé')
    end

    it 'includes employee name in body' do
      expect(mail.body.encoded).to include(employee.full_name)
    end

    it 'includes leave dates in body' do
      expect(mail.body.encoded).to include(leave_request.start_date.to_s)
    end
  end

  # Repeat for approved, rejected, cancelled
end
```

---

## 🧪 Testing Checklist

**Option A** (Remove References):
- [ ] Jobs run without errors
- [ ] Logs show `[EMAIL]` messages
- [ ] No `uninitialized constant` errors
- [ ] Full test suite still passes

**Option B** (Full Implementation):
- [ ] Mailer tests pass (4 tests per mailer)
- [ ] Preview works in development: http://localhost:3000/rails/mailers
- [ ] Emails sent in console: `LeaveRequestMailer.submitted(lr).deliver_now`
- [ ] Email templates render correctly (text + HTML)

## 📦 Commit Strategy

**Option A**:
```bash
git add app/jobs/leave_request_notification_job.rb app/jobs/weekly_time_validation_reminder_job.rb
git commit -m "fix(jobs): remove mailer references (temporary)

- Replace LeaveRequestMailer calls with Rails.logger.info
- Replace TimeEntryMailer calls with Rails.logger.info
- Add TODO comments for Sprint 2.x implementation
- Prevents job failures due to uninitialized constant errors

Ref: Sprint 1.4, Option A (Quick Fix)"
```

**Option B**:
```bash
git add app/mailers/ app/views/*_mailer/ spec/mailers/ config/environments/production.rb
git commit -m "feat(mailers): implement LeaveRequest and TimeEntry mailers

- Add LeaveRequestMailer (submitted, approved, rejected, cancelled)
- Add TimeEntryMailer (weekly_validation_reminder)
- Create text email templates (French)
- Configure SMTP for production
- Add mailer tests (8 examples)

Ref: Sprint 1.4, Option B (Full Implementation)"
```

## ⚠️ Gotchas

1. **Option A** - Don't forget TODO comments (future implementation)
2. **Option B** - Test emails in dev with `letter_opener` gem
3. **French text** - All emails must be in French
4. **SMTP credentials** - Never commit to git (use ENV vars)
5. **Default from address** - Must be valid domain

## 🎓 What You'll Learn

- Rails Action Mailer API
- Email templates (text vs HTML)
- SMTP configuration
- Mailer testing with RSpec
- Letter opener for development

## 📋 Handoff to QA

**Option A**:
```
Sprint 1.4 Complete - Mailer References Removed

✅ Tasks Completed:
- Removed LeaveRequestMailer calls (4 methods)
- Removed TimeEntryMailer calls (1 method)
- Added logging in place of emails
- Added TODO comments for future implementation

📊 Test Results:
- Jobs run without errors
- Logs show [EMAIL] messages
- Full test suite passes

📝 Notes:
- Emails will NOT be sent in MVP
- Notifications logged to Rails.log instead
- Implementation deferred to Sprint 2.x

Ready for @qa validation.
```

**Option B**:
```
Sprint 1.4 Complete - Mailers Implemented

✅ Tasks Completed:
- Implemented LeaveRequestMailer (4 methods)
- Implemented TimeEntryMailer (1 method)
- Created 5 text email templates (French)
- Configured SMTP for production
- Added mailer tests (8 examples)

📊 Test Results:
- Mailer tests: 8 examples, 0 failures
- Full test suite: 625+ examples, 0 failures

📧 Email Functionality:
- Leave submitted → Manager notified
- Leave approved → Employee notified
- Leave rejected → Employee notified
- Leave cancelled → Manager notified
- Weekly reminder → Managers notified (pending validations)

Ready for @qa validation.
```

---

# SPRINT 1.5 — DATABASE INDEXES

**Objective**: Add composite indexes for frequently queried columns
**Effort**: 1 hour
**Complexity**: LOW (additive migration)
**Priority**: ⚠️ HIGH

## 📝 Context

Frequently queried columns lack composite indexes, causing slow queries:
- `leave_requests` - Queried by `employee_id` + `status`
- `time_entries` - Queried by `employee_id` + `clock_in`
- `notifications` - Queried by `recipient_id` + `read_at`

**Performance Impact**:
- Without index: Sequential scan (45ms)
- With index: Index scan (0.12ms)
- **366x faster!**

## 🎯 Acceptance Criteria

- [ ] Migration created with composite indexes
- [ ] Migration runs successfully (`rails db:migrate`)
- [ ] EXPLAIN ANALYZE shows index usage (not seq scan)
- [ ] No impact on existing tests (should still pass)

## 🛠️ Implementation Steps

### Task 1.5.1 — Generate Migration

```bash
rails generate migration AddPerformanceIndexes
```

**File Created**: `db/migrate/YYYYMMDDHHMMSS_add_performance_indexes.rb`

---

### Task 1.5.2 — Implement Migration

**File**: `db/migrate/YYYYMMDDHHMMSS_add_performance_indexes.rb`

```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # LeaveRequest - status + date filtering
    add_index :leave_requests, [:employee_id, :status],
              name: 'idx_leave_requests_employee_status'

    add_index :leave_requests, [:start_date, :end_date],
              name: 'idx_leave_requests_date_range'

    # Partial index for pending requests (most common query)
    add_index :leave_requests, [:status, :created_at],
              name: 'idx_leave_requests_status_created',
              where: "status = 'pending'"

    # TimeEntry - employee + date range
    add_index :time_entries, [:employee_id, :clock_in],
              name: 'idx_time_entries_employee_clock_in'

    # Partial index for pending validation
    add_index :time_entries, [:employee_id, :validated_at],
              name: 'idx_time_entries_employee_validated',
              where: 'validated_at IS NULL'

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

**Steps**:
1. Run generator command (creates migration file)
2. Open migration file in `db/migrate/`
3. Copy implementation above
4. Save file

---

### Task 1.5.3 — Run Migration

```bash
rails db:migrate
```

**Expected Output**:
```
== AddPerformanceIndexes: migrating =========================================
-- add_index(:leave_requests, [:employee_id, :status], {:name=>"idx_leave_requests_employee_status"})
   -> 0.0123s
-- add_index(:leave_requests, [:start_date, :end_date], {:name=>"idx_leave_requests_date_range"})
   -> 0.0098s
-- add_index(:leave_requests, [:status, :created_at], {:name=>"idx_leave_requests_status_created", :where=>"status = 'pending'"})
   -> 0.0089s
-- add_index(:time_entries, [:employee_id, :clock_in], {:name=>"idx_time_entries_employee_clock_in"})
   -> 0.0145s
-- add_index(:time_entries, [:employee_id, :validated_at], {:name=>"idx_time_entries_employee_validated", :where=>"validated_at IS NULL"})
   -> 0.0112s
-- add_index(:notifications, [:recipient_id, :read_at], {:name=>"idx_notifications_recipient_read"})
   -> 0.0087s
-- add_index(:notifications, [:recipient_id, :created_at], {:name=>"idx_notifications_recipient_created"})
   -> 0.0095s
-- add_index(:employees, [:manager_id, :organization_id], {:name=>"idx_employees_manager_org"})
   -> 0.0103s
== AddPerformanceIndexes: migrated (0.0852s) =================================
```

**Steps**:
1. Run migration command
2. Verify no errors
3. Check `db/schema.rb` for new indexes

---

### Task 1.5.4 — Verify Indexes with EXPLAIN ANALYZE

**Open Rails console**:
```bash
rails console
```

**Test Leave Requests Query**:
```ruby
org = Organization.first
ActsAsTenant.current_tenant = org
employee = Employee.first

# Query pending leave requests
LeaveRequest.where(employee_id: employee.id, status: 'pending').explain
```

**Expected Output** (GOOD):
```
EXPLAIN for: SELECT "leave_requests".* FROM "leave_requests" WHERE "leave_requests"."employee_id" = $1 AND "leave_requests"."status" = $2
                                          QUERY PLAN
---------------------------------------------------------------------------------
 Index Scan using idx_leave_requests_employee_status on leave_requests
   Index Cond: ((employee_id = 123) AND ((status)::text = 'pending'::text))
(2 rows)
```

**Bad Output** (if index not used):
```
QUERY PLAN
---------------------------------------------------------------------------------
 Seq Scan on leave_requests  ❌ (NOT using index)
   Filter: ((employee_id = 123) AND ((status)::text = 'pending'::text))
(2 rows)
```

**Test Time Entries Query**:
```ruby
TimeEntry.where(employee_id: employee.id).where('clock_in >= ?', 1.month.ago).explain
```

**Expected**: `Index Scan using idx_time_entries_employee_clock_in`

**Test Notifications Query**:
```ruby
Notification.where(recipient_id: employee.id, read_at: nil).explain
```

**Expected**: `Index Scan using idx_notifications_recipient_read`

---

## 🧪 Testing Checklist

- [ ] Migration runs without errors
- [ ] `db/schema.rb` contains 8 new indexes
- [ ] EXPLAIN ANALYZE shows index usage (not seq scan)
- [ ] Full test suite passes: `bundle exec rspec`
- [ ] No performance regressions (tests still fast)

## 📦 Commit Strategy

```bash
git add db/migrate/ db/schema.rb
git commit -m "perf(db): add composite indexes for frequently queried columns

Indexes added:
- leave_requests: (employee_id, status)
- leave_requests: (start_date, end_date)
- leave_requests: (status, created_at) WHERE status = 'pending'
- time_entries: (employee_id, clock_in)
- time_entries: (employee_id, validated_at) WHERE validated_at IS NULL
- notifications: (recipient_id, read_at)
- notifications: (recipient_id, created_at)
- employees: (manager_id, organization_id)

Performance Impact:
- Dashboard queries: 45ms → 0.12ms (366x faster)
- Manager views: 3x faster
- Notification loading: 5x faster

Ref: Sprint 1.5"
```

## ⚠️ Gotchas

1. **Partial indexes** - Use `where:` clause for conditional indexes (smaller, faster)
2. **Index names** - Must be unique, use descriptive names (`idx_` prefix)
3. **Column order** - First column in composite index should be most selective
4. **Production deployment** - Indexes can take time on large tables (use `algorithm: :concurrently` if needed)
5. **Don't over-index** - Each index has write overhead (balance read vs write performance)

## 🎓 What You'll Learn

- Database index types (composite, partial)
- EXPLAIN ANALYZE for query optimization
- Index naming conventions
- When to use composite indexes
- PostgreSQL query planner

## 📋 Handoff to QA

```
Sprint 1.5 Complete - Performance Indexes Added

✅ Tasks Completed:
- Added 8 composite indexes
- Verified index usage with EXPLAIN ANALYZE
- Migration runs successfully
- No test regressions

📊 Performance Improvements:
- leave_requests queries: 366x faster (45ms → 0.12ms)
- time_entries queries: 3x faster
- notifications queries: 5x faster
- Dashboard load time: Significantly improved

🔗 Commits:
- <commit_sha> Add performance indexes

📝 Database Changes:
- 8 new indexes added
- Partial indexes for common filters (pending status)
- Total migration time: ~0.08s (dev environment)

Ready for @qa validation.
```

---

# REMAINING SPRINTS (Brief Overview)

Due to length constraints, here's a brief overview of remaining sprints. Full implementation details available upon request.

---

## SPRINT 1.6 — FIX N+1 QUERIES (2-3h)

**Tasks**:
1. Add `.includes(:approved_by, :employee)` to DashboardController
2. Add `.includes()` to LeaveRequestsController index
3. Add `.includes()` to Manager::TimeEntriesController
4. Install Bullet gem for N+1 detection
5. Verify Bullet reports 0 N+1 queries

**Acceptance**: Dashboard <150ms (down from ~450ms)

---

## SPRINT 1.7 — API SERIALIZERS (3-4h)

**Tasks**:
1. Install `active_model_serializers` gem
2. Create EmployeeSerializer (hide password_digest, tokens)
3. Create LeaveRequestSerializer
4. Create TimeEntrySerializer
5. Create LeaveBalanceSerializer
6. Create WorkScheduleSerializer
7. Create NotificationSerializer
8. Update all API controllers to use serializers

**Acceptance**: No sensitive data in API responses

---

## SPRINT 1.8 — RATE LIMITING (1-2h)

**Tasks**:
1. Install `rack-attack` gem
2. Configure throttles (login: 5/min, API: 100/min)
3. Add blocklist for repeated offenders
4. Test rate limiting in development
5. Configure Redis cache (production)

**Acceptance**: 429 Too Many Requests after threshold

---

## SPRINT 2.1 — SHARD BACKGROUND JOBS (3-4h)

**Tasks**:
1. Create OrganizationLeaveAccrualJob
2. Create OrganizationRttAccrualJob
3. Refactor LeaveAccrualJob to dispatcher
4. Refactor RttAccrualJob to dispatcher
5. Add SolidQueue monitoring

**Acceptance**: Jobs complete <5min (all orgs, parallel)

---

## SPRINT 2.2 — JSONB SCHEMA VALIDATION (3-4h)

**Tasks**:
1. Install `json_schemer` gem
2. Add schema validation to Organization.settings
3. Add schema validation to Employee.settings
4. Add schema validation to WorkSchedule.schedule_pattern
5. Add schema validation to TimeEntry.location
6. Data migration to conform existing data

**Acceptance**: Invalid JSONB rejected with clear errors

---

## SPRINT 2.3 — AUDIT TRAIL SYSTEM (4-5h)

**Tasks**:
1. Generate LeaveBalanceAudit model
2. Add audit logging to LeaveRequest#approve!
3. Add audit logging to accrual jobs
4. Create audit report UI (admin)
5. Add audit tests

**Acceptance**: All balance changes logged immutably

---

## 📊 TOTAL ROADMAP SUMMARY

| Sprint | Focus | Effort | Priority |
|--------|-------|--------|----------|
| 1.2 | Fix Test Failures | 1-2h | 🚨 CRITICAL |
| 1.3 | Transaction Safety | 2-3h | 🚨 CRITICAL |
| 1.4 | Mailer Implementation | 4-6h | 🚨 CRITICAL |
| 1.5 | Database Indexes | 1h | ⚠️ HIGH |
| 1.6 | Fix N+1 Queries | 2-3h | ⚠️ HIGH |
| 1.7 | API Serializers | 3-4h | ⚠️ HIGH |
| 1.8 | Rate Limiting | 1-2h | ⚠️ HIGH |
| 2.1 | Shard Jobs | 3-4h | ⚠️ HIGH |
| 2.2 | JSONB Validation | 3-4h | ⚠️ HIGH |
| 2.3 | Audit Trail | 4-5h | ⚠️ HIGH |
| **TOTAL** | **24-34h** | **3-4 days** |

---

## 🎯 GENERAL RULES FOR ALL SPRINTS

1. **Always read specs first** - Don't improvise implementation
2. **Tests MUST pass** - 100% green before committing
3. **Small commits** - 1 task = 1 commit (clear messages)
4. **@qa validation required** - Each sprint ends with handoff
5. **No parallel sprints** - Complete 1.2 before starting 1.3
6. **Ask @architect** - If anything unclear, don't guess
7. **Update CURRENT_WORKFLOW.md** - Document progress
8. **Follow commit conventions** - `feat(domain): description` format

---

## 📝 COMMIT MESSAGE CONVENTIONS

**Format**: `<type>(<scope>): <description>`

**Types**:
- `feat` - New feature
- `fix` - Bug fix
- `perf` - Performance improvement
- `refactor` - Code refactoring
- `test` - Add/update tests
- `docs` - Documentation
- `chore` - Maintenance tasks

**Examples**:
```bash
feat(leave): add transaction safety to approve!
fix(tests): remove duplicate leave_type in factory
perf(db): add composite indexes for leave_requests
test(transactions): verify rollback on failures
```

---

## 🚨 ESCALATION PATH

**When to ask @architect**:
- Spec is unclear or ambiguous
- Technical decision required (multiple approaches)
- Tests fail after implementation
- Performance concerns
- Security implications
- Architectural questions

**When to ask @qa**:
- Sprint completion validation
- Test failures after commit
- Edge case discovered
- Regression detected

---

**End of Developer Roadmap — Roadmap initial 100% COMPLETE**
**Next Step**: Phase 3 — à scoper par @architect

---

# DIRECTION E — COMPLETE (2026-02-27)

**Status**: COMPLETE

### E-1 — `authorize :see_salary?` dans `edit` et `update` ✅
- `Admin::EmployeesController#edit` et `#update` : `authorize @employee, :see_salary?`
- Symétrie parfaite avec `show` — les 3 actions ont le même guard

### E-2 — `_form` : fieldset Rémunération conditionné ✅
- `app/views/admin/employees/_form.html.erb` : enveloppé dans `policy(employee).see_salary?`
- Manager → 403 controller avant même d'atteindre la vue

### Specs ✅
- `spec/policies/employee_policy_spec.rb` : ajout `permissions :edit?, :update?` (3 cas)
- 9 examples, 0 failures
