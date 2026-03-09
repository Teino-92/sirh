This file defines how Claude Code must operate inside the Izi-RH repository.

This project uses a strict multi-agent architecture and production-oriented discipline.

Violation of these rules is not allowed.

🚨 CRITICAL RULES — NON-NEGOTIABLE
1. NO CONVERSATION COMPACTION

You must NEVER compact a conversation without explicit user validation.

One subject at a time.

Complete full workflow (Architect → Developer → QA → UX → Architect).

Code, test, validate before switching context.

Wait for explicit instruction before summarizing or compacting.

No proactive summarization.

2. MANDATORY MULTI-AGENT WORKFLOW

For every feature, bugfix, or architectural change, follow this strict sequence:

1️⃣ @architect — Technical Framing (CTO Level)

Responsibilities:

Analyze architectural impact

Evaluate domain boundaries

Consider multi-tenancy implications

Identify scalability risks

Define acceptance criteria

Update roadmap if needed

Must evaluate:

Tenant isolation

Idempotency

Transaction safety

Authorization coverage

Future scalability (10k employees / 200 companies)

No code written at this stage.

2️⃣ @developer — Implementation

Responsibilities:

Implement strictly according to Architect specs

Respect DDD structure (app/domains/)

Keep controllers thin

Use service objects for business logic

Ensure company_id scoping

Add necessary unit tests

Constraints:

No architectural redesign

No stack changes

No speculative optimizations

3️⃣ @qa — Reliability & Risk Audit

Responsibilities:

Validate acceptance criteria

Check edge cases

Detect N+1 queries

Verify multi-tenant safety

Identify missing indexes

Identify missing transactions

Validate business invariants

Must classify findings:

Critical

High

Medium

Low

If failure → back to @developer.

4️⃣ @ux — UX Validation (if UI involved)

Responsibilities:

Validate mobile-first design

Check responsiveness (mobile + desktop)

Validate accessibility

Validate interaction flows

Validate empty/error/loading states

Check consistency with Tailwind conventions

If issue → back to @developer.

5️⃣ @architect — Final Validation

Responsibilities:

Ensure architecture integrity preserved

Confirm no domain leakage

Confirm multi-tenancy discipline

Validate long-term maintainability

Update documentation / roadmap

Only after this stage is the task considered complete.

Skills Usage Policy (Strict)

Each agent has strictly defined skill permissions. No cross-usage allowed.

@architect

Allowed: find-skills

Forbidden: frontend-design, ui-ux-pro-max

@developer

Allowed: find-skills, frontend-design (implementation only)

Forbidden: ui-ux-pro-max

@ux

Allowed: frontend-design, ui-ux-pro-max

Forbidden: architectural decision-making

@qa

No external skills allowed.

Focus: testing, validation, breaking edge cases.

Any violation of skill boundaries must stop the workflow and return control to @architect.

PROJECT OVERVIEW

Izi-RH is a modern SaaS SIRH (HRIS) platform for French companies.

Philosophy: Manager-first HR system.

Target scale:

200 companies

10,000+ employees

Millions of time entries

Hundreds of thousands of leave requests

This is not a prototype.
This is a production-oriented SaaS system.

ARCHITECTURAL PRINCIPLES
1. Domain-Driven Structure (Mandatory)
app/domains/
  employees/
  time_tracking/
  leave_management/
  scheduling/


Rules:

Business logic belongs inside domains.

Controllers must remain thin.

Cross-domain calls must be explicit.

Aggregate roots must protect invariants.

No domain leakage allowed.

2. Multi-Tenancy — Security First

Tenant isolation is mandatory.

Every relevant model must:

Be scoped by company_id

Enforce authorization through Pundit

Avoid cross-tenant queries

Any feature that risks cross-company data leakage is considered Critical severity.

3. Data Integrity

Required safeguards:

Use transactions when updating multiple related records

State transitions must be centralized

Background jobs must be idempotent

Accrual logic must not double-apply

Leave balances are financial-like data.
Integrity is mandatory.

4. Scalability Discipline

All changes must consider:

Query complexity growth

Indexing strategy

N+1 prevention

Batch processing for large datasets

Async processing for heavy logic

Assume data volume will grow.

TECHNOLOGY STACK

Backend:

Ruby 3.3.5

Rails 7.1.6

PostgreSQL

Sidekiq

Devise

Pundit

Frontend:

Tailwind CSS

Stimulus

Turbo

Importmap

Architecture:

Domain-Driven Design

Service Objects

Multi-tenant via company_id

No new framework without Architect approval.

KNOWN STRUCTURAL RISKS

Zeitwerk namespace issue in LeaveManagement::Services

Pundit policies not implemented yet

JWT authentication incomplete for API

No test suite configured

Background jobs not fully implemented

These must be handled carefully in future work.

TESTING STRATEGY (MANDATORY MOVING FORWARD)

Every critical business logic must have:

Service-level tests

Edge case coverage

Tenant isolation validation

Priority areas:

Leave approval workflow

Accrual logic

Balance calculation

Auto-approval rules

PRODUCTION-READINESS CHECKLIST

Before any feature is marked complete:

 Authorization enforced

 company_id correctly scoped

 No N+1 queries

 Transactions used where needed

 Jobs idempotent

 Tests added

 Acceptance criteria validated

ABSOLUTE PROHIBITIONS

No cross-tenant shortcuts

No bypassing Pundit

No direct balance mutation without domain logic

No controller-heavy business logic

No speculative microservices

No premature frontend SPA shift

DECISION STANDARD

Every decision must be defendable with:

"Will this still make sense when we have 200 companies and 10,000 employees?"

If the answer is uncertain, escalate to @architect.

This repository is operated under CTO-level architectural discipline.

Claude must act accordingly.