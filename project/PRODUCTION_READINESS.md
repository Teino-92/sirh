# PRODUCTION READINESS — IZI-RH

**Date audit** : 2026-03-13
**Auditeur** : @architect
**Statut** : 🟡 EN PRODUCTION (Render free tier) — clients payants pas encore actifs

---

## RÉSUMÉ EXÉCUTIF

L'app est déployée et fonctionnelle sur izi-rh.com. Le flux billing Stripe est câblé et testé. Les fondations architecturales sont solides. Les gaps restants concernent la sécurité (JWT fallback, .find() non scopés), les tests du module billing, et l'infrastructure (Sentry, logs structurés).

---

## 🚨 CRITIQUE — À traiter avant 1er client payant

### C-1 · Secret JWT hardcodé dans le code source
**Fichier** : `config/initializers/devise.rb`
**Problème** : Fallback hardcodé — quiconque a accès au repo peut forger des tokens JWT.
```ruby
# CORRECT
jwt.secret = ENV.fetch('JWT_SECRET_KEY')
```
- [ ] Générer un nouveau secret : `rails secret`
- [ ] Définir `JWT_SECRET_KEY` dans les variables Render
- [ ] Supprimer le fallback hardcodé

---

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

### H-1 · `config.hosts` commenté — Host header injection
**Fichier** : `config/environments/production.rb`
- [ ] Activer `config.hosts = ["izi-rh.com", /.*\.izi-rh\.com/]`

### H-2 · Aucun error tracking (Sentry)
- [ ] `gem 'sentry-rails'` + `SENTRY_DSN` en env var

### H-3 · Logs non structurés
- [ ] `gem 'lograge'` avec formatter JSON

### H-4 · Devise mailer sender à `example.com`
**Fichier** : `config/initializers/devise.rb`
- [ ] `config.mailer_sender = 'noreply@izi-rh.com'`

### H-5 · Tests module billing à 0%
- [ ] Voir Phase 3 de la ROADMAP — priorité avant scaling

---

## 📋 MEDIUM

### M-1 · Bullet gem actif en production
- [ ] Wrapper dans `if Rails.env.development?`

### M-2 · ActiveStorage en stockage local (disk éphémère sur Render)
- [ ] Configurer S3/GCS pour les uploads

### M-3 · Coverage à ~20% — seuil insuffisant
- [ ] Cible : 40% minimum (voir ROADMAP Phase 3)

### M-4 · Rack::Attack sur MemoryStore
- [ ] Passe à Redis quand on upgrade Render (Phase 4)

---

## ✅ CE QUI EST EN PLACE

- ✅ Architecture DDD solide — domaines isolés, controllers thin
- ✅ Multi-tenancy via `acts_as_tenant` sur tous les modèles domaine
- ✅ Pundit — policies complètes pour toutes les ressources
- ✅ Stripe Checkout + Webhooks câblés et testés manuellement
- ✅ Trial 30 jours + expiry gate + email J-7
- ✅ Indexes DB — composite + partiels, queries critiques optimisées
- ✅ Transactions ACID sur mutations critiques (congés, accruals)
- ✅ ACID transactions billing (checkout, upgrade, webhooks)
- ✅ 619 tests passing (100%) sur logique métier core
- ✅ Zeitwerk fixé — boot propre en production
- ✅ SMTP Resend configuré et opérationnel
- ✅ Favicons + PWA basique

---

## VARIABLES D'ENVIRONNEMENT RENDER (état actuel)

| Variable | Statut | Note |
|----------|--------|------|
| `SECRET_KEY_BASE` | ✅ | Configuré |
| `STRIPE_SECRET_KEY` | ✅ | Mode test actif |
| `STRIPE_WEBHOOK_SECRET` | ✅ | Configuré |
| `STRIPE_PRICE_MANAGER_OS` | ✅ | Price ID test |
| `STRIPE_PRICE_SIRH_ESSENTIAL` | ✅ | Price ID test |
| `STRIPE_PRICE_SIRH_PRO` | ✅ | Price ID test |
| `APP_HOST` | ✅ | `izi-rh.com` |
| `SMTP_PASSWORD` | ✅ | Resend API key |
| `ADMIN_EMAIL` | ✅ | Email notifications admin |
| `JWT_SECRET_KEY` | ❌ | À configurer (C-1) |
| `SENTRY_DSN` | ❌ | Non configuré |

---

*Dernière mise à jour : 2026-03-13 par @architect*
