# Roadmap Izi-RH

**Dernière mise à jour** : 2026-03-14
**Version** : 1.5.0

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

### Critiques ✅
- ✅ H-1 : `config.hosts` activé en production (RENDER_EXTERNAL_HOSTNAME + APP_HOST)
- ✅ H-4 : Devise mailer sender — `DEVISE_MAILER_SENDER` env var (noreply@izi-rh.com)
- ✅ C-2 : TrainingAssignment.find scoped à l'organisation (seul modèle sans acts_as_tenant)

### Important ⏳
- [ ] H-5 : Sentry error tracking
- [ ] H-6 : Lograge (logs structurés JSON)
- [ ] M-1 : Bullet gem → development only
- [ ] M-2 : ActiveStorage → S3/GCS (vs local disk éphémère)

---

## Phase 5 — Fonctionnalités RH ✅ TERMINÉE (2026-03-14)

- ✅ Notifications email — 1:1 planifié/reprogrammé/annulé (employé notifié)
- ✅ Notifications email — Objectif assigné (employé notifié)
- ✅ Notifications email — Formation assignée (employé notifié)
- ✅ Périmètre RH — HR officer assignable à des départements (hr_perimeter)
- ✅ Référent RH — widget dashboard + affichage fiche employé
- ✅ DSN — Adresse postale dans le formulaire employé
- ✅ DSN — Convention collective depuis les paramètres organisation (pré-rempli)
- ✅ Dashboard manager SIRH — widget "Absences du jour" (équipe scopée)
- ✅ Dashboard — fix quick links crop (dernière ligne tronquée)

---

## Phase 6 — Scalabilité & Code Quality 🔮

- [ ] Background job sharding par organisation (LeaveAccrualJob, RttAccrualJob)
- [ ] Splitter LeavePolicyEngine en 4 services (~70 lignes chacun)
- [ ] API serializers (EmployeeSerializer, LeaveRequestSerializer, etc.)
- [ ] Partitioning time_entries par org_id + année
- [ ] CI/CD (GitHub Actions)
- [ ] Staging environment
- [ ] Migration Heroku (Redis + Sidekiq) quand scale le justifie

---

## Backlog 🔮

- Export Excel/PDF rapports
- Notifications temps réel (WebSocket)
- Régions Alsace-Moselle (jours fériés)
- Mobile app native (post-PWA)
- Dashboard analytics avancé
- Intégrations paie (Silae, PayFit)
- Coverage minimum 40%+

---

## Décisions techniques clés

| Date | Décision | Raison |
|------|----------|--------|
| 2026-01-13 | Workflow multi-agents strict | Qualité + traçabilité |
| 2026-01-13 | Tests avant refactoring | Filet de sécurité |
| 2026-02-27 | Render free tier (vs Heroku) | Coût MVP |
| 2026-03-13 | Stripe Checkout (vs custom) | Time-to-market |
| 2026-03-13 | async adapter (vs Sidekiq) | Render free tier sans worker |
| 2026-03-14 | acts_as_tenant sur tous les modèles sauf TrainingAssignment | Pas de organization_id — scoping contrôleur |
| 2026-03-14 | Convention collective dans org.settings (JSONB) | Saisie unique par org, override possible par employé |

---

*Mainteneur : Matteo Garbugli — mise à jour après chaque validation @architect*
