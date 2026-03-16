# PROJECT SUMMARY — IZI-RH

**Dernière mise à jour** : 2026-03-16
**Version** : 1.8.0
**Statut** : En production sur izi-rh.com — billing câblé, monitoring actif, pas encore de client payant
**Cible** : 200 organisations, 10 000+ employés

---

## RÉSUMÉ

Izi-RH est un SIRH SaaS **manager-first** pour les PME françaises. Architecture Domain-Driven Design, multi-tenancy strict, conformité Code du travail français. Déployé sur Render, billing via Stripe, emails via Resend, monitoring via Sentry.

---

## STACK TECHNIQUE

| Couche | Technologie |
|--------|------------|
| Backend | Ruby 3.3.5 / Rails 7.1.6 |
| Base de données | PostgreSQL (multi-tenant via acts_as_tenant) |
| Jobs | async adapter (Render free tier — pas de Sidekiq) |
| Auth | Devise (session) + JWT (API mobile — partiel) |
| Autorisation | Pundit |
| Frontend | Tailwind CSS v4, Stimulus, Turbo, Importmap |
| Billing | Stripe Checkout + Webhooks |
| Emails | Resend (API HTTP + SMTP) |
| Monitoring | Sentry (errors + profiling) + Lograge (JSON logs) |
| CI/CD | GitHub Actions (Brakeman + RSpec) |
| Infra | Render (web service + PostgreSQL free tier) |

---

## DOMAINES (app/domains/)

| Domaine | Contenu |
|---------|---------|
| `employees/` | Profils, hiérarchie, onboarding |
| `leave_management/` | CP, RTT, conformité légale française |
| `time_tracking/` | Pointage, validation, accrual RTT |
| `scheduling/` | Plannings hebdomadaires |
| `billing/` | Stripe, abonnements, webhooks |
| `onboarding/` | Templates, tâches, reviews |

---

## PLANS & TARIFICATION

| Plan | Prix | Cible |
|------|------|-------|
| Manager OS | 19 €/mois + 2 €/emp >10 | Équipes managériales |
| SIRH Essentiel | 59 €/mois + 4 €/emp >10 | PME avec RH |
| SIRH Pro | 159 €/mois + 6 €/emp >20 | PME avancées |

Trial gratuit 30 jours sans CB.

---

## ÉTAT DES FONCTIONNALITÉS

### ✅ Opérationnel
- Gestion des congés (CP, RTT, Maladie, Maternité, Paternité, Sans solde)
- LeavePolicyEngine — conformité Code du travail
- Pointage (clock in/out, validation manager)
- Plannings hebdomadaires
- 1:1, OKR, Formations, Évaluations, Onboarding
- Dashboard personnalisable (GridStack)
- Exports CSV (pointages, absences, paie)
- Billing Stripe (checkout, webhooks, abonnements, upgrade, résiliation)
- Trial 30 jours + gate expiry + email J-7
- Landing page izi-rh.com
- Panel admin (gestion employés, organisation, politiques congés)
- Email notif admin sur trial signup + souscription payante
- Super-admin analytics dashboard (`/super_admin/analytics`)
- Sentry error tracking + Lograge JSON logs
- CI/CD GitHub Actions (Brakeman + RSpec)
- **Rules Engine multi-domaines** — 14 triggers / 6 domaines (congés, 1:1, objectifs, formations, onboarding, évaluations)
- **Délégation de tâches** (`EmployeeDelegation`) — délégation d'approbation à un pair/N+1, UI complète, intégrée dans LeaveRequestPolicy

### 🔄 Partiel
- API mobile (JWT partiel, endpoints présents, sécurité à finaliser)

### ⏳ À faire
- Tests Rules Engine multi-domaines (couverture à compléter)
- Tests `EmployeeDelegation` (service + policy + controller)
- Migration Render → Heroku/Railway (Redis + Sidekiq) quand scale le justifie

---

## MÉTRIQUES TESTS (état 2026-03-16)

| Métrique | Valeur |
|----------|--------|
| Total tests | 1608+ |
| Tests passants | 100% |
| Coverage global | ~42% |
| Coverage LeavePolicyEngine | 100% |
| Coverage billing | ~80% (CheckoutService, UpgradeService, PaymentFailedHandler) |
| CI | GitHub Actions — Brakeman + RSpec |

---

## SÉCURITÉ MULTI-TENANT

- `acts_as_tenant` sur tous les modèles domaine
- `ApplicationController` set le tenant via `before_action`
- Background jobs utilisent `ActsAsTenant.with_tenant` explicite
- `RulesEngine#trigger` wrappé dans `ActsAsTenant.with_tenant` (fix C-2 phase 8)
- `NotificationJob` — employees filtrés par `organization_id` (fix C-1 phase 8)
- Pundit policies sur toutes les ressources

---

## DÉCISIONS ARCHITECTURALES CLÉS

| Date | Décision |
|------|----------|
| 2026-01-13 | DDD strict — services top-level (pas de namespaces Zeitwerk) |
| 2026-02-27 | Render free tier (async adapter, memory cache) |
| 2026-03-13 | Stripe Checkout (pas d'intégration custom) |
| 2026-03-15 | Super-admin via HTTP basic auth (indépendant de Devise) |
| 2026-03-15 | Sentry + Lograge + GitHub Actions CI |
| 2026-03-16 | Logo SVG inline (vs `<img dark:invert>`) — contrôle CSS fin light/dark |
| 2026-03-16 | `DelegationResolver` service centralisé — délégation réutilisable (policy + controller + scope) |
| 2026-03-16 | `fire_rules_engine` dans `BaseController` — rescue silencieux, RE ne casse jamais le flow |
| 2026-03-16 | Rules Engine étendu à 14 triggers / 6 domaines — moteur inchangé, call sites étendus |

---

*Mainteneur : Matteo Garbugli — Repository : Teino-92/sirh*
