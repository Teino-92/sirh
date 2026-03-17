# Roadmap Izi-RH

**Dernière mise à jour** : 2026-03-17
**Version** : 1.9.0

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

## Phase 7 — Scalabilité & Code Quality ✅ PARTIELLEMENT TERMINÉE (2026-03-16)

### Terminé
- ✅ LeavePolicyEngine splitté en 4 services (LeavePolicySettings, FrenchCalendar, LeaveAccrualCalculator, LeaveRequestValidator) — façade inchangée
- ✅ API serializers standalone (EmployeeSerializer, TimeEntrySerializer, LeaveRequestSerializer, LeaveBalanceSerializer, WorkScheduleSerializer) — 19 tests unitaires
- ✅ Staging environment — config prête, HTTP basic auth, seed auto (déploiement en attente 4 clients payants)
- ✅ Pricing per-seat documenté (MANAGER_OS_PER_SEAT_BILLING.md, SIRH_PER_SEAT_BILLING.md)
- ✅ 7 failures payroll specs corrigées (flash[:alert] direct vs follow_redirect!)
- ✅ CI assets:precompile — fix application.css missing en CI
- ✅ Rack::Attack nil fix — guard match_data nil dans throttled_responder
- ✅ 1608 tests, 0 failures — QA validé @architect

### En attente (conditionnel au volume)
- [ ] Background job sharding par organisation (LeaveAccrualJob, RttAccrualJob)
- [ ] Partitioning time_entries par org_id + année
- [ ] Migration Render → Heroku/Railway (Redis + Sidekiq) quand scale le justifie
- [ ] Rack::Attack sur Redis (vs memory_store actuel)

---

## Phase 8 — Workflows & Automatisations ✅ TERMINÉE (2026-03-16)

### Navbar & identité visuelle
- ✅ Navbar blanche en light mode (`bg-white dark:bg-gray-800`) — cohérence prod
- ✅ Logo SVG inline — `.logo-z` (indigo `#4F46E5`) + `.logo-rest` (indigo foncé `#1e1b4b`) en light, blanc en dark
- ✅ Suppression de `dark:invert` remplacé par contrôle CSS fin par classe

### Délégation de tâches (`EmployeeDelegation`)
- ✅ Modèle `EmployeeDelegation` avec `acts_as_tenant`, scopes `active_now` / `for_delegatee`
- ✅ Validation hiérarchique : délégation interdite vers les subordonnés directs (`not_a_direct_report`)
- ✅ `DelegationResolver` service centralisé (`can_act_as?`, `delegated_manager_ids`)
- ✅ Intégration `LeaveRequestPolicy` — `approve?`/`reject?` honorent les délégations actives
- ✅ Scope Pundit — les approbations déléguées apparaissent dans le tableau de bord manager
- ✅ `EmployeeDelegationPolicy` — create/destroy sécurisés (SIRH plan requis)
- ✅ UI complète — index (émises + reçues), formulaire de création (select pair/N+1 uniquement)
- ✅ Lien "Mes délégations" dans le dropdown profil (conditionné plan SIRH)
- ✅ Routes `resources :employee_delegations, only: [:index, :new, :create, :destroy]`

### Rules Engine multi-domaines
- ✅ Extension de 4 triggers (congés) à **14 triggers** couvrant 6 domaines métier
- ✅ 1:1 : `one_on_one.scheduled`, `one_on_one.completed`
- ✅ Objectifs : `objective.assigned`, `objective.completed`
- ✅ Formations : `training_assignment.assigned`, `training_assignment.completed`
- ✅ Onboarding : `onboarding.started`, `onboarding.task_completed`
- ✅ Évaluations : `evaluation.completed`
- ✅ `fire_rules_engine` helper dans `Manager::BaseController` — rescue silencieux, DRY
- ✅ `NotificationJob` — `organization_id` obligatoire, employees filtrés par org (C-1)
- ✅ `RulesEngine#trigger` wrappé dans `ActsAsTenant.with_tenant` (C-2)
- ✅ `ALLOWED_RESOURCE_TYPES` étendue dans les jobs (`NotificationJob`, `ApprovalEscalationJob`)
- ✅ Stimulus `rule_builder_controller.js` — map `TRIGGER_FIELDS` dynamique par trigger
- ✅ Form admin — `grouped_collection_select` trigger par domaine + `data-rule-builder-trigger-value`
- ✅ `BusinessRulesHelper` — 14 triggers + FIELD_LABELS multi-domaines
- ✅ QA complet — 4 findings critiques/hauts corrigés :
  - C-1 : `NotificationJob` multi-tenancy leak corrigé
  - C-2 : `for_trigger` sans scope tenant corrigé
  - H-1 : crash nil `employee_onboarding` corrigé (includes + nil guard)
  - H-2 : `fire_rules_engine` rescue empêche cassure du flow principal
  - H-3 : `pluck(:id)` N+1 remplacé par JOIN direct
  - L-1 : XSS innerHTML corrigé via `_escapeHtml`

### En attente (conditionnel au volume)
- [ ] Background job sharding par organisation (LeaveAccrualJob, RttAccrualJob)
- [ ] Partitioning time_entries par org_id + année
- [ ] Migration Render → Heroku/Railway (Redis + Sidekiq) quand scale le justifie
- [ ] Rack::Attack sur Redis (vs memory_store actuel)

---

## Phase 8b — OrgMerge : Fusion organisations Manager OS → SIRH ✅ TERMINÉE (2026-03-17)

### Fusion cross-tenant
- ✅ `OrgMergeInvitation` — modèle cross-tenant (pas d'`acts_as_tenant`), token sécurisé (32 bytes URL-safe, expiry 7 jours)
- ✅ Validations métier : target doit être SIRH, source doit être Manager OS, pas d'invitation active en cours
- ✅ `OrgMergePreviewService` — preview des données à migrer (comptes par modèle) avant acceptation
- ✅ `OrgMergeService` — transaction ACID + `ActsAsTenant.without_tenant`, 23 modèles migrés, dissolution source
- ✅ `with_lock` sur l'org source pour éviter double-merge concurrent
- ✅ Stripe cancel + `sub.update_columns` **hors** transaction (cohérence DB/Stripe préservée)
- ✅ `OrgMergeJob` — idempotence via `update_all WHERE status='accepted'` atomique
- ✅ `OrgMergeMailerService` — email invitation (Resend/Faraday) + email completion admin
- ✅ `CGI.escapeHTML` sur toutes les variables interpolées dans les mailers HTML (XSS)
- ✅ `OrgMergeInvitationPolicy` — Pundit, `hr_or_admin? && sirh?`
- ✅ Admin UI — index invitations + formulaire création
- ✅ Page publique acceptation — `skip_before_action authenticate + check_trial_expired` (lien email sans auth)
- ✅ Transition `pending→accepted` atomique dans le controller (double-enqueue prevention)
- ✅ QA complet — 4 CRITICAL + 3 HIGH corrigés avant merge

---

## Phase 8c — Per-Seat Billing Stripe ✅ TERMINÉE (2026-03-17)

- ✅ `SeatSyncService` — sync quantité Stripe après create/deactivate employé (Manager OS + SIRH)
- ✅ `SyncSeatCountJob` — async, idempotent, re-raise Stripe error pour retry
- ✅ Gate Manager OS : confirmation via token session (`SecureRandom.hex` + `secure_compare`) — anti-forgery
- ✅ `authorize_admin!` étendu à `manager_os?` (était bloqué sur `sirh?` uniquement)
- ✅ `active_seat_count` memoïsé — 1 seule query SQL (DRY)
- ✅ ENV var manquante → log error + Sentry (plus de no-op silencieux)
- ✅ `SubscriptionItem.create` uniquement si `quantity > 0` (évite les invoices €0)
- ✅ Fix désactivation : `key?('active')` vs `false.present?`
- ✅ QA complet — 2 CRITICAL + 3 HIGH + 3 MEDIUM corrigés avant merge
- ✅ Prix Stripe créés : Manager OS seat (2 €), SIRH Essentiel seat (3 €), SIRH Pro seat (2,50 €)

---

## Phase 9 — Intégration Calendrier OAuth2 ⏳ PLANIFIÉE

> Sprint architecturalement défini — implémentation non démarrée.

### Objectif

Permettre à chaque employé de connecter son compte Google ou Microsoft pour que ses 1:1 et formations soient automatiquement synchronisés dans son calendrier personnel.

### Modèle `EmployeeOauthToken`

- `organization_id` (FK, `acts_as_tenant`, contrainte hard multi-tenant)
- `employee_id` + `provider` (`google` | `microsoft`) — unique par paire
- `access_token` chiffré AR Encryption non-deterministic
- `refresh_token` chiffré AR Encryption non-deterministic
- `uid` chiffré deterministic (lookup au callback OAuth)
- `expires_at`, `scopes`, `revocation_status` (`active` | `revoked` | `expired`)

### Gems à ajouter

```ruby
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-microsoft-graph", "~> 2.0"
gem "omniauth-rails_csrf_protection", "~> 1.0"
```

Faraday est déjà dans le Gemfile — utilisé pour les appels API Calendar.

### Services

| Service | Responsabilité |
|---|---|
| `Calendar::GoogleCalendarService` | CRUD Google Calendar API (Faraday) |
| `Calendar::MicrosoftCalendarService` | CRUD Microsoft Graph API (Faraday) |
| `Calendar::TokenRefresher` | refresh `access_token` avant chaque appel (lazy) |
| `Calendar::TokenRevoker` | révocation API + marque `revoked` |
| `Calendar::CalendarEventBuilder` | construit le payload event depuis `OneOnOne` / `TrainingAssignment` |

### Job : `Calendar::PushEventJob`

- Action : `upsert` ou `delete`
- `ActsAsTenant.with_tenant(record.organization)` explicite
- Guard cross-tenant : `token.organization_id != record.organization_id` → log + Sentry + return
- `retry_on RateLimitError`, `discard_on TokenRevokedError`
- Rescue silencieux — ne jamais propager au request cycle

### Idempotency

`metadata['google_calendar_event_id']` et `metadata['microsoft_calendar_event_id']` sur `OneOnOne` et `TrainingAssignment`. Si présent → PATCH (update), sinon → POST (create) + stocker l'ID retourné.

### Points de déclenchement

| Événement | Action calendrier |
|---|---|
| OneOnOne créé | upsert (manager + employé) |
| OneOnOne date modifiée | upsert |
| OneOnOne annulé | delete |
| TrainingAssignment créé | upsert (employé) |
| TrainingAssignment completed / cancelled | delete |

### Structure fichiers prévue

```
app/domains/calendar_integration/
  models/employee_oauth_token.rb
  services/
    google_calendar_service.rb
    microsoft_calendar_service.rb
    token_refresher.rb
    token_revoker.rb
    calendar_event_builder.rb

app/controllers/auth/
  oauth_callbacks_controller.rb     (create, destroy, failure)

app/jobs/calendar/
  push_event_job.rb

app/policies/
  employee_oauth_token_policy.rb
```

Routes :

```
scope '/auth' do
  get  ':provider/callback',     to: 'auth/oauth_callbacks#create'
  get  ':provider/failure',      to: 'auth/oauth_callbacks#failure'
  post ':provider',              to: 'auth/oauth_callbacks#passthru'
  delete 'disconnect/:provider', to: 'auth/oauth_callbacks#destroy'
end
```

### Risques identifiés

| # | Risque | Sévérité | Mitigation |
|---|--------|----------|-----------|
| R-1 | Google refresh_token absent (pas retourné si consentement déjà donné) | Élevé | `prompt: 'consent'` + `access_type: 'offline'` obligatoires |
| R-2 | Cross-tenant injection dans job async | Critique | Guard explicite `token.org_id != record.org_id` + test dédié |
| R-3 | Perte de jobs sur Render au redémarrage (async adapter in-memory) | Moyen | Best-effort V1 — migrer vers SolidQueue avant 50+ orgs actives |
| R-4 | `invalid_grant` (refresh_token révoqué après 6 mois inactivité) | Élevé | `discard_on TokenRevokedError` + notification in-app employé |
| R-5 | Google OAuth review process (scope `calendar.events` sensible) | Moyen | Prévoir délai avant publication — OK en test avec comptes listés |

### Acceptance Criteria

| # | Critère | Niveau |
|---|---------|--------|
| AC-1 | Employé connecte Google Calendar depuis son profil (consentement → callback → token stocké) | Critical |
| AC-2 | Employé connecte Microsoft Outlook depuis son profil | Critical |
| AC-3 | 1:1 créé → event dans le calendrier du manager ET de l'employé si connectés | Critical |
| AC-4 | Formation assignée → event dans le calendrier de l'employé si connecté | Critical |
| AC-5 | Date 1:1 modifiée → event mis à jour (pas recréé) | Critical |
| AC-6 | 1:1 annulé → event supprimé | Critical |
| AC-7 | Re-exécuter le job deux fois → pas de doublon (idempotency) | High |
| AC-8 | Déconnecter révoque le token côté Google/Microsoft + détruit le record | High |
| AC-9 | Token révoqué/expiré → notification in-app + aucune propagation d'erreur au flow | High |
| AC-10 | Token org A inaccessible depuis org B — validé par test d'intégration | Critical |
| AC-11 | `access_token` + `refresh_token` absents des logs (filter_parameters) | Critical |
| AC-12 | Employé sans token connecté → aucune erreur visible | High |

### Prérequis avant implémentation

- [ ] Enregistrement Google Cloud Console (activer Calendar API, configurer OAuth consent screen, scope `calendar.events`)
- [ ] Enregistrement Azure AD (App registration, `Calendars.ReadWrite` + `offline_access`)
- [ ] Variables d'env : `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`
- [ ] Redirect URIs enregistrées : dev (`localhost:3000`) + prod (`izi-rh.com`)

---

## Phase 10 — Intégration paie : Silae / PayFit ⏳ PLANIFIÉE

> Sprint architecturalement à définir — implémentation non démarrée.

### Objectif

Permettre aux organisations SIRH d'exporter leurs données de paie vers Silae ou PayFit automatiquement à chaque clôture de période.

---

## Backlog 🔮

- Export Excel/PDF rapports
- Notifications temps réel (WebSocket)
- Régions Alsace-Moselle (jours fériés)
- Mobile app native (post-PWA)

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
| 2026-03-16 | LeavePolicyEngine → façade + 4 services | Maintenabilité, testabilité |
| 2026-03-16 | Serializers standalone (vs concern controller) | Réutilisabilité hors controllers |
| 2026-03-16 | Pricing per-seat Manager OS (6 inclus) + SIRH (30/50 inclus) | B2C manager + B2B RH |
| 2026-03-16 | Staging en attente (code prêt, DB coût justifié à 4 clients) | Free tier = 1 DB max |
| 2026-03-16 | Logo SVG inline (vs `<img dark:invert>`) | Contrôle fin couleurs light/dark sans double asset |
| 2026-03-16 | `DelegationResolver` service centralisé | Évite duplication logique délégation dans policy + controller |
| 2026-03-16 | `fire_rules_engine` dans BaseController (rescue silencieux) | RE ne doit jamais casser le flow principal |
| 2026-03-16 | Rules Engine : 14 triggers / 6 domaines | Workflows custom pour tous les domaines SIRH, moteur inchangé |
| 2026-03-16 | Intégration calendrier via OAuth2 (pas ICS) | Sync bidirectionnelle native, experience employé sans friction |
| 2026-03-16 | omniauth (vs Faraday manuel) pour OAuth2 | Gestion CSRF/state/callback battle-tested, moins de surface d'attaque |
| 2026-03-16 | Lazy refresh token (vs job proactif) | Suffisant en V1 (actions user-triggered), job proactif en V2 |
| 2026-03-16 | `EmployeeOauthToken` modèle dédié (vs `employee.settings`) | Chiffrement AR garanti, audit trail, révocation propre, pas de sérialisation JSONB |
| 2026-03-17 | `OrgMergeInvitation` sans `acts_as_tenant` | Cross-tenant par nature — scoping tenant intentionnellement absent, accès via token public |
| 2026-03-17 | Stripe cancel hors transaction ACID OrgMerge | Stripe est externe — rollback DB ne peut pas rollback Stripe ; cancel après commit garantit cohérence |
| 2026-03-17 | `update_all WHERE status=...` pour idempotence job | Atomicité SQL > `update` AR qui lit puis écrit (race condition TOCTOU) |
| 2026-03-17 | Per-seat via token session (vs param `seat_confirmed`) | Param forgeable par curl — token session lié à la session Rails, timing-safe via `secure_compare` |
| 2026-03-17 | `SeatSyncService` re-raise Stripe error | Job doit être retryable — swallow silencieux = billing stale sans alerte |
| 2026-03-17 | Seat item créé uniquement si quantity > 0 | Évite invoices Stripe €0 qui polluent l'historique client |

---

*Mainteneur : Matteo Garbugli — mise à jour après chaque validation @architect*
