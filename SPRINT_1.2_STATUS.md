# Sprint 1.2 Status Report

**Date**: 2026-02-16
**Developer**: @developer
**Status**: BLOCKED - Needs @architect clarification

## Issue

Roadmap specifies fixing 14 test failures:
- 9 failures: LeaveBalance uniqueness
- 3 failures: Organization I18n
- 2 failures: Organization NOT NULL

## Current Reality

Running `bundle exec rspec` shows:
- **615 examples, 5 failures, 3 pending**
- Coverage: 19.93%

## Actual Failures Found

1. **LeaveBalance scopes .expiring_soon** (3 failures)
   - `spec/domains/leave_management/models/leave_balance_spec.rb:367`
   - `spec/domains/leave_management/models/leave_balance_spec.rb:471`
   - `spec/domains/leave_management/models/leave_balance_spec.rb:513`
   - Issue: Tests expect balances expiring exactly 3 months from now to be included in scope

2. **TimeEntry scopes** (2 failures)
   - `spec/domains/time_tracking/models/time_entry_spec.rb:339` - .this_week
   - `spec/domains/time_tracking/models/time_entry_spec.rb:418` - .validated_this_week
   - Issue: "Overlapping time entry detected" validation error

## Work Completed

✅ Task 1.2.1 - Fixed LeaveBalance uniqueness (line 335)
- Removed `leave_type: 'CP'` parameter
- This fixed 6 failures (not 9)

✅ Task 1.2.2 - Organization I18n tests
- Already passing (French locale messages correct)

✅ Task 1.2.3 - Organization NOT NULL tests
- Not found in current spec file

## Discrepancy

Roadmap describes different failures than what exists in codebase. Either:
1. Roadmap based on outdated test run
2. Tests have changed since roadmap creation
3. I'm running wrong branch/commit

## Question for @architect

Should I:
1. Fix the 5 current failures (different from roadmap)?
2. Skip Sprint 1.2 and proceed to Sprint 1.3?
3. Wait for updated roadmap?

## Test Output

```
Finished in 3.5 seconds (files took 1.96 seconds to load)
615 examples, 5 failures, 3 pending

Failed examples:

rspec ./spec/domains/leave_management/models/leave_balance_spec.rb:367
rspec ./spec/domains/leave_management/models/leave_balance_spec.rb:471
rspec ./spec/domains/leave_management/models/leave_balance_spec.rb:513
rspec ./spec/domains/time_tracking/models/time_entry_spec.rb:339
rspec ./spec/domains/time_tracking/models/time_entry_spec.rb:418
```

## Files Modified

- `spec/domains/leave_management/models/leave_balance_spec.rb` (line 336)
  - Removed `leave_type: 'CP'` parameter per roadmap Task 1.2.1

## Awaiting Guidance

Cannot proceed with Sprint 1.2 until @architect confirms which failures to fix.
