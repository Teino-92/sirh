# Roadmap Izi-RH

**Dernière mise à jour** : 2026-03-13
**Version** : 1.3.0

---

## Légende

- ✅ Terminé et validé
- 🔄 En cours
- ⏳ Planifié
- 🔮 Futur (non daté)

---

## Phase 0 — Infrastructure & Fondations ✅ TERMINÉE

- ✅ Rails 7.1.6 + PostgreSQL + Tailwind CSS v4 + Dark mode
- ✅ Devise authentication + Pundit authorization
- ✅ Multi-tenancy (acts_as_tenant)
- ✅ Domain-Driven Design (app/domains/)
- ✅ PWA setup basique

---

## Phase 1 — Production Readiness ✅ TERMINÉE (2026-02-16)

- ✅ Sprint 1.2 — 619/619 tests passing (100%), SimpleCov actif
- ✅ Sprint 1.3 — Transactions ACID sur toutes les mutations critiques
- ✅ Sprint 1.4 — Background jobs opérationnels (mailers loggés temporairement)
- ✅ Sprint 1.5 — 6 index composites + 2 partiels (queries 366x plus rapides)
- ✅ Sprint 1.6 — Eager loading, N+1 éliminés (82-99% de réduction queries)

---

## Phase 2 — Produit & Billing ✅ TERMINÉE (2026-03-13)

- ✅ Landing page live sur izi-rh.com
- ✅ Trial 30 jours avec expiry gate + email J-7
- ✅ Stripe Checkout câblé (Manager OS, SIRH Essentiel, SIRH Pro)
- ✅ Webhooks Stripe (checkout.completed, subscription.updated, payment.succeeded/failed)
- ✅ Tunnel abonnement post-trial + gestion abonnement actif
- ✅ Upgrade Essentiel → Pro (self-service Stripe)
- ✅ Upgrade Manager OS → SIRH (formulaire de contact admin)
- ✅ Résiliation avec protection engagement 12 mois
- ✅ Zeitwerk fixé — tous les services sont des constantes top-level
- ✅ Déploiement Render (free tier, PostgreSQL, SMTP Resend)
- ✅ QA audit billing complet — webhooks robustes, sync plan, sécurité

---

## Phase 3 — Tests & Qualité 🔄 EN COURS

**Priorité** : CRITIQUE avant toute acquisition client

### 3.1 — Tests module Billing ⏳
- [ ] `spec/domains/billing/services/checkout_service_spec.rb`
- [ ] `spec/domains/billing/services/billing_service_spec.rb`
- [ ] `spec/domains/billing/services/subscription_upgrade_service_spec.rb`
- [ ] `spec/domains/billing/webhooks/checkout_completed_handler_spec.rb`
- [ ] `spec/domains/billing/webhooks/subscription_updated_handler_spec.rb`
- [ ] `spec/domains/billing/webhooks/payment_succeeded_handler_spec.rb`
- [ ] `spec/domains/billing/webhooks/payment_failed_handler_spec.rb`
- [ ] `spec/domains/billing/models/subscription_spec.rb`
- [ ] `spec/policies/billing_policy_spec.rb`
- **Cible** : 100% logique billing testée

### 3.2 — Tests Trial & Organisation ⏳
- [ ] `spec/models/organization_spec.rb` — trial_active?, trial_expired?, trial_days_remaining
- [ ] `spec/services/trial_registration_service_spec.rb`
- [ ] `spec/controllers/trial_registrations_controller_spec.rb`

### 3.3 — Tests Controllers ⏳
- [ ] `spec/controllers/billings_controller_spec.rb`
- [ ] `spec/controllers/stripe_webhooks_controller_spec.rb`
- [ ] Tests API v1 (dashboard, time_entries, leave_requests)

### 3.4 — Tests Policies ⏳
- [ ] BillingPolicy (show, create_checkout, upgrade, cancel)
- [ ] EmployeePolicy, LeaveRequestPolicy, TimeEntryPolicy

### 3.5 — Tests Jobs & Mailers ⏳
- [ ] LeaveAccrualJob, RttAccrualJob
- [ ] AdminUpgradeMailer, BillingMailer

---

## Phase 4 — Sécurité & Infrastructure ⏳ PLANIFIÉE

### Critiques (avant 1er client payant)
- [ ] C-1 : JWT secret — supprimer fallback hardcodé dans devise.rb
- [ ] C-3 : `.find()` non scopés → `policy_scope(Model).find()` dans 5 controllers
- [ ] H-2 : Activer `config.hosts` en production
- [ ] H-7 : Corriger Devise mailer sender (example.com → noreply@izi-rh.com)

### Important
- [ ] H-5 : Sentry error tracking
- [ ] H-6 : Lograge (logs structurés JSON)
- [ ] M-1 : Bullet gem → development only
- [ ] M-2 : ActiveStorage → S3/GCS (vs local disk ephémère)
- [ ] M-3 : Coverage minimum → 40%

---

## Phase 5 — Scalabilité & Code Quality 🔮

- [ ] Background job sharding par organisation (LeaveAccrualJob, RttAccrualJob)
- [ ] Splitter LeavePolicyEngine en 4 services (~70 lignes chacun)
- [ ] API serializers (EmployeeSerializer, LeaveRequestSerializer, etc.)
- [ ] Partitioning time_entries par org_id + année
- [ ] CI/CD (GitHub Actions)
- [ ] Staging environment

---

## Backlog 🔮

- Mailers complets (leave_request, time_entry)
- Export Excel/PDF rapports
- Notifications temps réel (WebSocket)
- Régions Alsace-Moselle (jours fériés)
- Mobile app native (post-PWA)
- Dashboard analytics avancé
- Intégrations paie (Silae, PayFit)

---

## Décisions techniques clés

| Date | Décision | Raison |
|------|----------|--------|
| 2026-01-13 | Workflow multi-agents strict | Qualité + traçabilité |
| 2026-01-13 | Tests avant refactoring | Filet de sécurité |
| 2026-02-27 | Render free tier (vs Heroku) | Coût MVP |
| 2026-03-13 | Stripe Checkout (vs custom) | Time-to-market |
| 2026-03-13 | async adapter (vs Sidekiq) | Render free tier sans worker |

---

*Mainteneur : Matteo Garbugli — mise à jour après chaque validation @architect*
