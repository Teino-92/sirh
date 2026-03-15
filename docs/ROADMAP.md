# Roadmap Izi-RH

**Dernière mise à jour** : 2026-03-15
**Version** : 1.6.0

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

## Phase 3 — Tests & Qualité ✅ TERMINÉE (2026-03-14)

- ✅ 3.1 — Tests module Billing (services, webhooks handlers, subscription model, BillingPolicy)
- ✅ 3.2 — Tests Trial & Organisation (organization_spec, trial_registration_service, controller)
- ✅ 3.3 — Tests Controllers (billings_controller, stripe_webhooks_controller)
- ✅ 3.4 — Tests Policies (BillingPolicy, EmployeePolicy, LeaveRequestPolicy, TimeEntryPolicy, OneOnOnePolicy)
- ✅ 3.5 — Tests Jobs & Mailers (AdminUpgradeMailer, BillingMailer, OneOnOneMailer, ObjectiveMailer, TrainingAssignmentMailer)

---

## Phase 4 — Sécurité & Infrastructure ✅ TERMINÉE (2026-03-14)

- ✅ H-1 : `config.hosts` activé en production (RENDER_EXTERNAL_HOSTNAME + APP_HOST)
- ✅ H-4 : Devise mailer sender — `DEVISE_MAILER_SENDER` env var (noreply@izi-rh.com)
- ✅ C-2 : TrainingAssignment.find scoped à l'organisation

---

## Phase 5 — Fonctionnalités RH ✅ TERMINÉE (2026-03-14)

- ✅ Notifications email — 1:1 planifié/reprogrammé/annulé
- ✅ Notifications email — Objectif assigné, Formation assignée
- ✅ Périmètre RH — HR officer assignable à des départements
- ✅ Référent RH — widget dashboard + affichage fiche employé
- ✅ DSN — Adresse postale + Convention collective
- ✅ Dashboard manager SIRH — widget "Absences du jour"

---

## Phase 6 — Monitoring, Observabilité & Sécurité ✅ TERMINÉE (2026-03-15)

### Monitoring & Logs
- ✅ Sentry error tracking (sentry-ruby + sentry-rails + stackprof, prod only)
- ✅ Lograge logs JSON structurés avec user_id/org_id par requête
- ✅ Alertes Slack via Sentry (nouvelles erreurs, répétitions, trial failures)

### CI/CD
- ✅ GitHub Actions — Brakeman security scan + RSpec sur chaque push
- ✅ Brakeman 0 warnings (`.brakeman.ignore` pour faux positifs documentés)
- ✅ SimpleCov seuil relevé à 40% (suite à ~42%)

### Sécurité
- ✅ JWT_SECRET_KEY — plus de fallback hardcodé, `ENV.fetch` strict en prod
- ✅ `policy_scope` sur tous les `.find(params[:id])` — double protection tenant + Pundit
- ✅ Super-admin analytics `/super_admin/analytics` — HTTP basic auth indépendant de Devise

### Notifications admin
- ✅ Email admin à chaque nouveau trial signup
- ✅ Email admin à chaque nouvelle souscription payante (webhook Stripe)

### Stockage
- ✅ Cloudinary free tier pour Active Storage avatars (plus de disk éphémère Render)

### Tests billing complétés
- ✅ CheckoutService — 11 tests (customer creation, trial_end, Stripe error, tenant isolation)
- ✅ SubscriptionUpgradeService — 12 tests (self-service, admin upgrade, rollback)
- ✅ PaymentFailedHandler — 10 tests (status update, email, early returns, tenant isolation)

---

## Phase 7 — Scalabilité & Code Quality 🔮

- [ ] Background job sharding par organisation (LeaveAccrualJob, RttAccrualJob)
- [ ] Splitter LeavePolicyEngine en 4 services (~70 lignes chacun)
- [ ] API serializers (EmployeeSerializer, LeaveRequestSerializer, etc.)
- [ ] Partitioning time_entries par org_id + année
- [ ] Staging environment
- [ ] Migration Heroku/Railway (Redis + Sidekiq) quand scale le justifie
- [ ] Rack::Attack sur Redis (vs memory_store actuel)

---

## Backlog 🔮

- Export Excel/PDF rapports
- Notifications temps réel (WebSocket)
- Régions Alsace-Moselle (jours fériés)
- Mobile app native (post-PWA)
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
| 2026-03-14 | acts_as_tenant sur tous les modèles sauf TrainingAssignment | Pas de organization_id |
| 2026-03-14 | Convention collective dans org.settings (JSONB) | Saisie unique par org |
| 2026-03-15 | Cloudinary (vs S3) pour Active Storage | Free tier permanent, pas de CB |
| 2026-03-15 | Super-admin via HTTP basic auth | Indépendant de Devise + DB |

---

*Mainteneur : Matteo Garbugli — mise à jour après chaque validation @architect*
