# PRODUCTION READINESS — IZI-RH

**Date audit** : 2026-03-15
**Auditeur** : @architect
**Statut** : 🟡 EN PRODUCTION (Render free tier) — clients payants pas encore actifs

---

## RÉSUMÉ EXÉCUTIF

L'app est déployée et fonctionnelle sur izi-rh.com. Sentry + Lograge sont en place. Le CI/CD GitHub Actions tourne. Les gaps restants concernent la sécurité (JWT fallback, `.find()` non scopés) et la couverture de tests.

---

## 🚨 CRITIQUE — À traiter avant 1er client payant

### C-1 · Secret JWT hardcodé dans le code source
**Fichier** : `config/initializers/devise.rb`
**Problème** : Fallback hardcodé — quiconque a accès au repo peut forger des tokens JWT.
```ruby
jwt.secret = ENV.fetch('JWT_SECRET_KEY')
```
- [ ] Générer un nouveau secret : `rails secret`
- [ ] Définir `JWT_SECRET_KEY` dans les variables Render
- [ ] Supprimer le fallback hardcodé

### C-2 · `.find()` non scopés — fuite cross-tenant possible
**Fichiers** : `one_on_ones_controller.rb`, `objectives_controller.rb`, `training_assignments_controller.rb`, `leave_requests_controller.rb`, `manager/time_entries_controller.rb`
**Problème** : `Model.find(params[:id])` sans scoping tenant — si un bug Pundit existe, breach directe.
```ruby
# CORRECT
@record = policy_scope(Model).find(params[:id])
```
- [ ] Auditer et corriger les 5 controllers concernés
- [ ] Ajouter tests d'isolation cross-tenant

---

## ⚠️ HIGH — Requis avant mise à l'échelle

### H-1 · Tests module billing à 0%
- [ ] Écrire les tests Stripe webhook handlers
- [ ] Écrire les tests CheckoutService / BillingService

### H-2 · Coverage global insuffisant (~20%)
- [ ] Cible : 40% minimum
- [ ] Priorité : controllers admin, services critiques

---

## 📋 MEDIUM

### M-1 · Bullet gem actif en production
- [ ] Wrapper dans `if Rails.env.development?`

### M-2 · ActiveStorage en stockage local (disk éphémère sur Render)
- [ ] Configurer S3 pour les uploads avatars
- [ ] `STORAGE_SERVICE=s3` + credentials AWS

### M-3 · Rack::Attack sur MemoryStore
- [ ] Passer à Redis quand on upgrade Render

---

## ✅ FAIT

- ✅ Architecture DDD solide — domaines isolés, controllers thin
- ✅ Multi-tenancy via `acts_as_tenant` sur tous les modèles domaine
- ✅ Pundit — policies complètes pour toutes les ressources
- ✅ Stripe Checkout + Webhooks câblés et testés manuellement
- ✅ Trial 30 jours + expiry gate + email J-7
- ✅ Indexes DB — composite + partiels, queries critiques optimisées
- ✅ Transactions ACID sur mutations critiques (congés, accruals, billing)
- ✅ 619+ tests passing (100%) sur logique métier core
- ✅ Zeitwerk fixé — boot propre en production
- ✅ SMTP Resend configuré et opérationnel
- ✅ **Sentry** error tracking (sentry-ruby + sentry-rails + stackprof)
- ✅ **Lograge** logs JSON structurés avec user_id/org_id
- ✅ **CI/CD GitHub Actions** — Brakeman + RSpec sur chaque push
- ✅ **Email admin** — notif trial signup + souscription payante
- ✅ **Super-admin analytics** — dashboard `/super_admin/analytics` (HTTP basic auth)
- ✅ config.hosts activé (Render + APP_HOST)
- ✅ Devise mailer sender → `noreply@izi-rh.com`
- ✅ Brakeman 0 warnings (fichier `.brakeman.ignore` pour faux positifs documentés)

---

## VARIABLES D'ENVIRONNEMENT RENDER (état actuel)

| Variable | Statut | Note |
|----------|--------|------|
| `SECRET_KEY_BASE` | ✅ | Configuré |
| `STRIPE_SECRET_KEY` | ✅ | Mode live |
| `STRIPE_WEBHOOK_SECRET` | ✅ | Configuré |
| `APP_HOST` | ✅ | `izi-rh.com` |
| `SMTP_PASSWORD` | ✅ | Resend API key |
| `ADMIN_NOTIFICATION_EMAIL` | ✅ | `matteo.garbugli@yahoo.it` |
| `SENTRY_DSN` | ✅ | Configuré |
| `SUPER_ADMIN_LOGIN` | ✅ | Configuré |
| `SUPER_ADMIN_PASSWORD` | ✅ | Configuré |
| `JWT_SECRET_KEY` | ❌ | À configurer (C-1) |
| `RAILS_MASTER_KEY` | ⚠️ | GitHub Secret pour CI |

---

*Dernière mise à jour : 2026-03-15 par @architect*
