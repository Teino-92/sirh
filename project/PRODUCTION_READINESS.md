# PRODUCTION READINESS — EASY-RH

**Date audit** : 2026-02-27
**Auditeur** : @architect
**Statut** : 🔴 NON PRÊT — 3 blockers critiques à résoudre avant tout déploiement

---

## RÉSUMÉ EXÉCUTIF

La base architecturale est solide (DDD, multi-tenancy, Solid Queue, Paper Trail, Pundit).
Les gaps sont principalement des **oublis de configuration prod** et **3 vulnérabilités de sécurité** à traiter en priorité absolue.

Estimation : **3 semaines** pour un lancement sécurisé.

---

## 🚨 CRITIQUE — Bloquants absolus (traiter avant tout déploiement)

### C-1 · Secret JWT hardcodé dans le code source
**Fichier** : `config/initializers/devise.rb` ligne 318
**Problème** : Fallback hardcodé dans le code — quiconque a accès au repo peut forger des tokens JWT valides pour n'importe quel compte.
```ruby
# ACTUEL — DANGEREUX
jwt.secret = ENV.fetch('JWT_SECRET_KEY', 'a7f472e60ae68e5eb449bc24e91959073c326019...')

# CORRECT
jwt.secret = ENV.fetch('JWT_SECRET_KEY')  # lève KeyError si absent → fail fast
```
**Actions** :
- [ ] Générer un nouveau secret : `rails secret`
- [ ] Définir `JWT_SECRET_KEY` dans les variables d'environnement de production
- [ ] Supprimer le fallback hardcodé dans le code
- [ ] Invalider tous les tokens actifs (changer le secret force la re-auth)
- [ ] Purger la valeur de l'historique git : `git filter-repo --path config/initializers/devise.rb`

---

### C-2 · Clé API Anthropic commitée en clair
**Fichier** : `.env` (présent dans `.gitignore` mais potentiellement dans l'historique git)
**Problème** : La clé `sk-ant-api03-...` est exposée. Si elle a été commitée à un moment, elle est dans l'historique.
**Actions** :
- [ ] **Révoquer immédiatement** la clé dans la console Anthropic (console.anthropic.com)
- [ ] Créer une nouvelle clé et la stocker uniquement dans les vars d'env de production
- [ ] Vérifier l'historique git : `git log --all --full-history -- .env`
- [ ] Si présente dans l'historique : `git filter-repo --path .env --invert-paths`
- [ ] Ajouter `.env.example` avec les clés vides comme template documenté
- [ ] Mettre en place un scan de secrets en CI (ex: `trufflehog`, `gitleaks`)

---

### C-3 · `.find()` non scopés — fuite cross-tenant possible
**Fichiers concernés** :
- `app/controllers/one_on_ones_controller.rb`
- `app/controllers/objectives_controller.rb`
- `app/controllers/training_assignments_controller.rb`
- `app/controllers/leave_requests_controller.rb`
- `app/controllers/manager/time_entries_controller.rb`

**Problème** : Ces controllers utilisent `Model.find(params[:id])` sans scoping tenant, puis délèguent à Pundit. Si un bug existe dans une policy, c'est une breach directe de données entre organisations.

```ruby
# ACTUEL — RISQUÉ
@one_on_one = OneOnOne.find(params[:id])
authorize @one_on_one

# CORRECT — défense en profondeur
@one_on_one = policy_scope(OneOnOne).find(params[:id])
# ou
@one_on_one = current_organization.one_on_ones.find(params[:id])
```
**Actions** :
- [ ] Auditer tous les controllers (app/controllers/ et sous-dossiers)
- [ ] Remplacer chaque `Model.find()` par `policy_scope(Model).find()` ou scope organisation
- [ ] Ajouter des tests d'isolation cross-tenant pour chaque ressource concernée
- [ ] Vérifier également les controllers API (app/controllers/api/v1/)

---

## ⚠️ HIGH — Requis avant mise en production

### H-1 · CSP (Content Security Policy) entièrement commenté
**Fichier** : `config/initializers/content_security_policy.rb`
**Problème** : Aucun header CSP envoyé → pas de protection XSS côté navigateur.
**Actions** :
- [ ] Décommenter et configurer la CSP minimale
- [ ] Activer le nonce pour les scripts inline Stimulus/Alpine
- [ ] Tester que AlpineJS CDN est dans la whitelist (`cdn.jsdelivr.net`)
- [ ] Configurer un endpoint `/csp-violation-report-endpoint` (ou Sentry)

---

### H-2 · `config.hosts` commenté — Host header injection
**Fichier** : `config/environments/production.rb` lignes 108-113
**Problème** : Sans liste blanche de hosts, les liens de reset de mot de passe et les notifications peuvent être poisonnés.
**Actions** :
- [ ] Décommenter et configurer avec le(s) domaine(s) réel(s)
- [ ] Exclure `/up` (health check) du host check
```ruby
config.hosts = ["app.easy-rh.com", /.*\.easy-rh\.com/]
config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
```

---

### H-3 · `config.require_master_key` commenté
**Fichier** : `config/environments/production.rb` ligne 21
**Problème** : Sans cette option, un déploiement sans `master.key` peut démarrer silencieusement avec des credentials non déchiffrés.
**Actions** :
- [ ] Décommenter `config.require_master_key = true`
- [ ] S'assurer que `RAILS_MASTER_KEY` est défini dans tous les environnements de déploiement

---

### H-4 · Rack::Attack sur MemoryStore — rate limiting inefficace en prod
**Fichier** : `config/initializers/rack_attack.rb` ligne 7
**Problème** : Le cache mémoire ne survit pas aux redémarrages et ne fonctionne pas en cas de plusieurs instances (load balancing). Un attaquant peut bruteforcer en distribuant les requêtes.
**Actions** :
- [ ] Changer pour `Rack::Attack.cache.store = Rails.cache`
- [ ] S'assurer que `config.cache_store = :redis_cache_store` est configuré en production avec `REDIS_URL`

---

### H-5 · Aucun error tracking (Sentry/Rollbar/Honeybadger)
**Problème** : Les exceptions en production (jobs d'accrual, notifications, calculs payroll) passeront silencieusement. Impossible de détecter une breach ou un bug critique.
**Actions** :
- [ ] Ajouter `gem 'sentry-rails'` et `gem 'sentry-sidekiq'` au Gemfile
- [ ] Configurer `SENTRY_DSN` en variable d'environnement
- [ ] Créer `config/initializers/sentry.rb`
- [ ] Configurer le breadcrumb Sidekiq/Solid Queue
- [ ] Tester qu'une exception dans un job remonte bien dans Sentry

---

### H-6 · Aucun logging structuré (Lograge)
**Problème** : Les logs Rails par défaut sont multilignes et non structurés — impossibles à agréger dans un système centralisé (CloudWatch, ELK, Datadog).
**Actions** :
- [ ] Ajouter `gem 'lograge'` au Gemfile
- [ ] Configurer dans `config/environments/production.rb` :
```ruby
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_options = lambda do |event|
  { organization_id: event.payload[:organization_id] }
end
```
- [ ] Connecter à un service de logs centralisé

---

### H-7 · Devise mailer sender à `example.com`
**Fichier** : `config/initializers/devise.rb` ligne 27
**Problème** : Les emails Devise (reset mot de passe, confirmation) partent avec `please-change-me-at-config-initializers-devise@example.com` comme expéditeur.
**Actions** :
- [ ] `config.mailer_sender = ENV.fetch('DEVISE_MAILER_SENDER', 'noreply@easy-rh.com')`

---

### H-8 · Redis URL avec fallback localhost en production
**Fichier** : `config/cable.yml`
**Problème** : Si `REDIS_URL` n'est pas défini, Action Cable tente de se connecter à `redis://localhost:6379/1` — qui n'existe pas sur un serveur de production cloud.
**Actions** :
- [ ] Passer de `ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" }` à `ENV.fetch("REDIS_URL")`
- [ ] Documenter `REDIS_URL` dans les variables d'environnement requises

---

## 📋 MEDIUM — Important mais non bloquant pour un MVP

### M-1 · Bullet gem activé sans garde en production
**Fichier** : `config/initializers/bullet.rb`
**Actions** :
- [ ] Wrapper dans `if Rails.env.development?` pour éviter logs parasites et footer HTML en prod

---

### M-2 · ActiveStorage en stockage local
**Fichier** : `config/environments/production.rb` ligne 105 — `config.active_storage.service = :local`
**Problème** : Ne scale pas sur plusieurs instances, fichiers perdus au redémarrage du container.
**Actions** :
- [ ] Configurer un service S3/GCS dans `config/storage.yml`
- [ ] `config.active_storage.service = :amazon` (ou `:google`)
- [ ] Définir les credentials AWS/GCS en variables d'environnement

---

### M-3 · Coverage à 19% — seuil trop bas
**Fichier** : `spec/spec_helper.rb` — `minimum_coverage 19`
**Actions** :
- [ ] Monter le seuil à 40% (`minimum_coverage 40`)
- [ ] Écrire des tests pour les services de calcul (accrual, payroll, onboarding scores)
- [ ] Ajouter des specs d'isolation multi-tenant explicites (org A ne voit pas org B)
- [ ] Couvrir tous les flows d'approbation congés (edge cases)

---

### M-4 · Pas de rate limiting sur les exports CSV
**Problème** : Un manager peut exporter massivement les données employés sans limite.
**Actions** :
- [ ] Ajouter dans `config/initializers/rack_attack.rb` :
```ruby
throttle('exports/user', limit: 5, period: 1.hour) do |req|
  req.env['warden']&.user&.id if req.path.include?('/export')
end
```

---

### M-5 · Image Docker non pinnée par digest SHA
**Fichier** : `Dockerfile` ligne 4
**Problème** : Un rebuild futur peut inclure une version Ruby avec une vulnérabilité.
**Actions** :
- [ ] Épingler l'image par SHA256 : `FROM ruby:3.3.5-slim@sha256:<hash>`
- [ ] Mettre en place un processus de mise à jour mensuelle des images de base

---

## 🔵 LOW — Améliorations post-lancement

### L-1 · X-Frame-Options manquant
**Actions** :
- [ ] Ajouter dans `config/application.rb` :
```ruby
config.action_dispatch.default_headers['X-Frame-Options'] = 'SAMEORIGIN'
```

---

### L-2 · Assets non servis via CDN
**Actions** :
- [ ] Configurer `config.asset_host` avec un CDN (CloudFront/Cloudflare)
- [ ] Héberger les assets statiques hors du serveur applicatif

---

### L-3 · AlpineJS depuis CDN externe sans SRI hash
**Fichier** : `app/views/layouts/application.html.erb` et `admin.html.erb`
**Problème** : `<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/...">` sans `integrity=` ni version exacte.
**Actions** :
- [ ] Épingler la version exacte (ex: `alpinejs@3.14.1`)
- [ ] Ajouter l'attribut `integrity="sha384-..."` (SRI hash)
- [ ] Ou importer Alpine via importmap pour éviter le CDN externe

---

### L-4 · JWT expiration à 1 jour — UX mobile dégradée
**Fichier** : `config/initializers/devise.rb` — `jwt.expiration_time = 1.day.to_i`
**Actions** :
- [ ] Évaluer si le refresh token flow est correctement implémenté
- [ ] Envisager 7 jours avec rotation automatique à chaque requête authentifiée

---

### L-5 · Cleanup Active Storage variants non planifié
**Actions** :
- [ ] Créer un job hebdomadaire pour purger les blobs non attachés :
```ruby
ActiveStorage::Blob.unattached.where('created_at < ?', 1.week.ago).find_each(&:purge_later)
```

---

## VARIABLES D'ENVIRONNEMENT REQUISES EN PRODUCTION

Documenter et valider que toutes ces variables sont définies avant le premier déploiement :

| Variable | Obligatoire | Description |
|----------|-------------|-------------|
| `SECRET_KEY_BASE` | ✅ OUI | Rails session secret |
| `JWT_SECRET_KEY` | ✅ OUI | Secret de signature JWT (minimum 64 chars) |
| `RAILS_MASTER_KEY` | ✅ OUI | Déchiffrement credentials.yml.enc |
| `DATABASE_URL` | ✅ OUI | URL PostgreSQL de production |
| `REDIS_URL` | ✅ OUI | URL Redis (cache + Action Cable + Solid Queue) |
| `ANTHROPIC_API_KEY` | ✅ OUI | Clé API Claude Haiku (HR Query Engine) |
| `RAILS_SMTP_HOST` | ✅ OUI | Serveur SMTP sortant |
| `RAILS_SMTP_PORT` | ✅ OUI | Port SMTP (587 recommandé) |
| `RAILS_SMTP_USERNAME` | ✅ OUI | Username SMTP |
| `RAILS_SMTP_PASSWORD` | ✅ OUI | Mot de passe SMTP |
| `DEVISE_MAILER_SENDER` | ✅ OUI | Adresse expéditeur Devise |
| `SENTRY_DSN` | ⚠️ RECOMMANDÉ | DSN Sentry error tracking |
| `ASSET_HOST` | 🔵 OPTIONNEL | CDN hostname pour les assets |
| `ACTIVE_STORAGE_SERVICE` | 🔵 OPTIONNEL | `:amazon` ou `:google` (défaut: `:local`) |
| `AWS_ACCESS_KEY_ID` | 🔵 OPTIONNEL | Si ActiveStorage sur S3 |
| `AWS_SECRET_ACCESS_KEY` | 🔵 OPTIONNEL | Si ActiveStorage sur S3 |
| `AWS_REGION` | 🔵 OPTIONNEL | Si ActiveStorage sur S3 |
| `AWS_BUCKET` | 🔵 OPTIONNEL | Si ActiveStorage sur S3 |

---

## CHECKLIST DE DÉPLOIEMENT

### Semaine 1 — Sécurité critique
- [ ] C-1 : Rotater JWT secret + supprimer fallback hardcodé
- [ ] C-2 : Révoquer clé Anthropic + purger historique git
- [ ] C-3 : Fixer tous les `.find()` non scopés (audit + fix + tests)
- [ ] H-2 : Activer `config.hosts`
- [ ] H-3 : Activer `config.require_master_key = true`
- [ ] H-7 : Corriger Devise mailer sender

### Semaine 2 — Infrastructure prod
- [ ] H-1 : Configurer CSP
- [ ] H-4 : Rack::Attack → Redis cache
- [ ] H-5 : Installer et configurer Sentry
- [ ] H-6 : Installer et configurer Lograge
- [ ] H-8 : Forcer REDIS_URL sans fallback localhost
- [ ] M-2 : Passer ActiveStorage sur S3/GCS
- [ ] M-1 : Bullet gem → development only

### Semaine 3 — Qualité et tests
- [ ] M-3 : Monter coverage à 40%
- [ ] M-4 : Rate limiting sur les exports
- [ ] L-1 : X-Frame-Options
- [ ] L-3 : AlpineJS — version épinglée + SRI hash
- [ ] Valider toutes les variables d'environnement
- [ ] Load test (simulation 200 orgs, 10k employees)
- [ ] Smoke test complet sur staging

### Feu vert production ✅
- [ ] 0 finding CRITIQUE ouvert
- [ ] 0 finding HIGH ouvert
- [ ] Coverage ≥ 40%
- [ ] Sentry actif et recevant des événements de test
- [ ] Backup DB testé et restauration validée
- [ ] Rollback plan documenté

---

## CE QUI EST DÉJÀ BIEN

- ✅ Architecture DDD solide — domaines isolés, controllers thin
- ✅ Multi-tenancy via `acts_as_tenant` sur tous les modèles domaine
- ✅ Pundit — policies complètes pour toutes les ressources
- ✅ Paper Trail — audit trail tenant-scopé sur LeaveBalance, LeaveRequest, EmployeeOnboarding
- ✅ Indexes DB — composite + partiels, queries critiques optimisées
- ✅ Solid Queue — 3 queues dédiées (schedulers, accruals, default)
- ✅ Rack::Attack — throttling présent (cache à corriger)
- ✅ JSONB validation — concern custom sans gem externe
- ✅ NL-to-Filters — jamais de SQL généré par le LLM
- ✅ Salary gating — re-validé server-side indépendamment du LLM
- ✅ JWT + JwtDenylist — révocation fonctionnelle
- ✅ Health check `/up` — endpoint Rails natif présent
- ✅ SSRF guard — `Organization#safe_calendar_webhook_url` valide les URLs

---

*Dernière mise à jour : 2026-02-27 par @architect*
