# Izi-RH — Infrastructure par phase

Une seule app Rails. Un seul codebase. La différence entre Manager OS et SIRH
est uniquement `organizations.plan` — pas deux déploiements séparés.

---

## Phase 1 — Validation marché (0€/mois)

Objectif : tester, démo, premiers utilisateurs. Pas de SLA, sleep acceptable.

| Composant     | Service          | Plan       | Coût  | Notes                          |
|---------------|------------------|------------|-------|--------------------------------|
| App Rails     | Render.com       | **Starter** | ~7€   | Pas de sleep, SLA 99.95%       |
| PostgreSQL    | Render.com       | Free        | 0€    | PostgreSQL lié via render.yaml |
| Jobs          | Render.com       | Starter (async adapter) | 0€ | Pas de worker séparé — Upstash + Sidekiq au 1er client SIRH |
| Emails        | Resend           | Free        | 0€    | 3 000 emails/mois              |
| Fichiers      | Cloudinary       | Free        | 0€    | Avatars Active Storage         |
| CI/CD         | GitHub Actions   | Free        | 0€    | 2 000 min/mois                 |
| DNS / SSL     | Cloudflare       | Free        | 0€    | SSL automatique                |

**Total : ~7€/mois** (Render Starter depuis 2026-03-20)

### Variables d'environnement Render (Phase 1)

```
RAILS_ENV=production
RAILS_MASTER_KEY=<master.key>
DATABASE_URL=<supabase_connection_string>
RAILS_SERVE_STATIC_FILES=true
WEB_CONCURRENCY=2
RAILS_MAX_THREADS=5
```

### Limites à accepter en Phase 1

- L'app s'endort après 15min sans trafic (premier chargement ~30s)
- Pas de worker Solid Queue séparé → jobs traités dans le process web
- 500MB PostgreSQL → suffisant pour ~50 organisations de test
- Pas de backups automatiques sur Supabase Free

---

## Phase 2 — Premiers clients payants (~30-50€/mois)

Objectif : SLA correct, pas de sleep, backups, emails illimités.

| Composant     | Service          | Plan           | Coût/mois | Notes                     |
|---------------|------------------|----------------|-----------|---------------------------|
| App Rails     | Render.com       | Starter        | ~7€       | Pas de sleep, 512MB RAM   |
| Worker Jobs   | Render.com       | Starter        | ~7€       | Process Solid Queue séparé|
| PostgreSQL    | Supabase         | Pro            | ~25€      | 8GB, backups quotidiens   |
| Emails        | Resend           | Pro            | ~17€      | 50 000 emails/mois        |
| Fichiers      | Cloudflare R2    | Pay-as-you-go  | <1€       | Quasi gratuit             |
| CI/CD         | GitHub Actions   | Free           | 0€        |                           |
| DNS / SSL     | Cloudflare       | Free           | 0€        |                           |
| Monitoring    | Sentry           | Free           | 0€        | 5 000 erreurs/mois        |

**Total : ~55€/mois**

### Ce qui change vs Phase 1

- Worker Solid Queue séparé → jobs fiables, pas de contention avec Puma
- Supabase Pro → backups quotidiens, connection pooling, 8GB
- Render Starter → pas de cold start, uptime garanti
- Resend Pro → volume emails suffisant pour 200 orgs

### Procfile (Phase 2 — deux process)

```
web: bundle exec puma -C config/puma.rb
worker: bundle exec rake solid_queue:start
```

Déjà configuré dans `Procfile`.

---

## Phase 3 — Scale (200 orgs / 10 000 employés)

Objectif : haute dispo, autoscaling, observabilité complète.

| Composant     | Service          | Plan              | Coût/mois  | Notes                        |
|---------------|------------------|-------------------|------------|------------------------------|
| App Rails     | Render.com       | Standard (x2)     | ~50€       | 2 instances, autoscaling     |
| Worker Jobs   | Render.com       | Standard          | ~25€       | Worker dédié avec RAM        |
| PostgreSQL    | Supabase         | Pro + Read replica| ~100€      | Read replica pour reporting  |
| Cache         | Upstash Redis    | Pay-as-you-go     | ~10€       | Solid Cache → Redis si besoin|
| Emails        | Resend           | Business          | ~85€       | 100 000 emails/mois          |
| Fichiers      | Cloudflare R2    | Pay-as-you-go     | ~5€        |                              |
| CDN Assets    | Cloudflare       | Free              | 0€         |                              |
| Monitoring    | Sentry           | Team             | ~26€       | Alertes, performance         |
| Logs          | Papertrail       | Choklad (~10€)    | ~10€       | Rétention 1 semaine          |
| DNS / SSL     | Cloudflare       | Free              | 0€         |                              |

**Total : ~310€/mois** pour 200 orgs → ~1.55€/org/mois d'infrastructure

---

## Upgrade path entre phases

```
Phase 1 → Phase 2 :
  1. Render : passer Free → Starter (clic dans dashboard)
  2. Supabase : passer Free → Pro (clic dans dashboard)
     → connection string ne change pas
  3. Activer le worker Solid Queue séparé sur Render
  4. Configurer Resend Pro

Phase 2 → Phase 3 :
  1. Render : ajouter une 2ème instance web + autoscaling
  2. Supabase : activer read replica
  3. Évaluer Redis si Solid Cache devient un goulot
```

Aucune migration de données entre phases. Même app, même DB, mêmes variables d'environnement.

---

## Ce qui n'est PAS dans ce fichier (à définir)

- Stripe / billing (intégration paiement)
- Custom domain par client (subdomain strategy)
- RGPD / hébergement EU (Supabase EU region : `eu-west-1`)
- Backup strategy avancée (pg_dump automatique vers R2)
- Secrets management (Render env vars suffisent en Phase 1/2, Vault en Phase 3)
