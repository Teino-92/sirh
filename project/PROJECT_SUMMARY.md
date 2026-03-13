# PROJECT SUMMARY — IZI-RH

**Dernière mise à jour** : 2026-03-13
**Version** : 1.3.0
**Statut** : En production sur izi-rh.com — billing câblé, pas encore de client payant
**Cible** : 200 organisations, 10 000+ employés

---

## RÉSUMÉ

Izi-RH est un SIRH SaaS **manager-first** pour les PME françaises. Architecture Domain-Driven Design, multi-tenancy strict, conformité Code du travail français. Déployé sur Render, billing via Stripe, emails via Resend.

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

Engagement 12 mois à la souscription, puis mensuel sans engagement.
Trial gratuit 30 jours sans CB.

---

## ÉTAT DES FONCTIONNALITÉS

### ✅ Opérationnel
- Gestion des congés (CP, RTT, Maladie, Maternité, Paternité, Sans solde)
- LeavePolicyEngine — conformité Code du travail (153 tests, 100% couverture)
- Pointage (clock in/out, validation manager)
- Plannings hebdomadaires
- 1:1, OKR, Formations, Évaluations, Onboarding
- Dashboard personnalisable (GridStack)
- Exports CSV (pointages, absences, paie)
- Billing Stripe (checkout, webhooks, abonnements, upgrade, résiliation)
- Trial 30 jours + gate expiry + email J-7
- Landing page izi-rh.com
- Panel admin (gestion employés, organisation, politiques congés)

### 🔄 Partiel
- API mobile (JWT partiel, endpoints présents, sécurité à finaliser)
- Notifications email (infrastructure en place, templates à compléter)

### ⏳ Planifié
- Tests module billing (Phase 3 ROADMAP)
- Sentry + Lograge (Phase 4)
- Job sharding par organisation

---

## MÉTRIQUES TESTS (état 2026-02-16)

| Métrique | Valeur |
|----------|--------|
| Total tests | 619 |
| Tests passants | 619 (100%) |
| Coverage global | ~20% |
| Coverage LeavePolicyEngine | 100% |
| Coverage billing | 0% (à faire) |

---

## SÉCURITÉ MULTI-TENANT

- `acts_as_tenant` sur tous les modèles domaine
- `ApplicationController` set le tenant via `before_action`
- Background jobs utilisent `ActsAsTenant.with_tenant`
- Pundit policies sur toutes les ressources
- ⚠️ 5 controllers avec `.find()` non scopé (voir PRODUCTION_READINESS.md C-2)

---

## DÉCISIONS ARCHITECTURALES CLÉS

| Date | Décision |
|------|----------|
| 2026-01-13 | DDD strict — services top-level (pas de namespaces Zeitwerk) |
| 2026-01-13 | Tests avant refactoring (Sprint 1 dédié) |
| 2026-02-27 | Render free tier (async adapter, memory cache) |
| 2026-03-13 | Stripe Checkout (pas d'intégration custom) |
| 2026-03-13 | Manager OS founder = rôle admin |

---

*Mainteneur : Matteo Garbugli — Repository : Teino-92/sirh*
