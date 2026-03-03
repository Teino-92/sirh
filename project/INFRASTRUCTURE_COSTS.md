# INFRASTRUCTURE COSTS — EASY-RH

**Date** : 2026-02-27
**Auditeur** : @architect
**Stack** : Rails 7.1 + PostgreSQL + Solid Queue + Redis + SMTP externe

> Tous les prix sont en **€/mois HT**, basés sur les tarifs AWS Europe (Paris `eu-west-3`) et équivalents.
> Les prix tiers (Postmark, Sentry, Anthropic) sont en USD — taux 1 USD ≈ 0.93 EUR appliqué.

---

## HYPOTHÈSES DE CHARGE

| Paramètre | Lancement | Croissance | Cible |
|-----------|-----------|------------|-------|
| Organisations | 5–10 | 50 | 200 |
| Employés totaux | 50–200 | 2 000 | 10 000 |
| Requêtes web/jour | ~500 | ~20 000 | ~100 000 |
| Time entries/mois | ~5 000 | ~200 000 | ~2 000 000 |
| Jobs/mois | ~1 000 | ~50 000 | ~500 000 |
| Emails/mois | ~200 | ~5 000 | ~30 000 |
| Requêtes LLM/mois | ~20 | ~500 | ~3 000 |
| Stockage DB | ~1 GB | ~20 GB | ~150 GB |

---

## SCÉNARIO A — LANCEMENT (MVP, 5–10 orgs)

> Objectif : valider le produit au minimum de coût. Pas de redondance.

### Compute — Web App
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| App server | **Fly.io** Machine | 1 vCPU / 512 MB RAM (`shared-cpu-1x`) | ~5 € |
| OU App server | **Render** Starter | 512 MB RAM | ~7 € |
| OU App server | **Railway** | 512 MB / 1 vCPU | ~5 € |

**Retenu : Fly.io shared-cpu-1x → ~5 €/mois**
*(1 Puma process, 3 threads, WEB_CONCURRENCY=1)*

### Background Jobs (Solid Queue)
Solid Queue tourne **dans le même processus** ou dans un second container minimal.
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| Job worker | Fly.io Machine | `shared-cpu-1x` 256 MB | ~3 € |

### Base de données
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| PostgreSQL | **Fly.io Postgres** | 1 shared vCPU / 256 MB / 1 GB SSD | ~0 € (free tier) |
| OU PostgreSQL | **Supabase Free** | 500 MB storage | 0 € |
| OU PostgreSQL | **Neon Free** | 3 GB storage | 0 € |

**Retenu : Neon Free → 0 €/mois** (suffisant pour le lancement)

### Redis
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| Redis | **Upstash** Free | 256 MB, 10k commands/day | 0 € |
| OU Redis | **Fly.io Redis** | Upstash intégré | 0 € |

**Retenu : Upstash Free → 0 €/mois**

### Email transactionnel
| Composant | Choix | Volume | Prix/mois |
|-----------|-------|--------|-----------|
| SMTP | **Resend** Free | 3 000 emails/mois | 0 € |
| OU SMTP | **Brevo** Free | 300 emails/jour | 0 € |
| OU SMTP | **Postmark** | 100 emails/mois offerts | 0 € |

**Retenu : Resend Free → 0 €/mois**

### Stockage fichiers (ActiveStorage)
| Composant | Choix | Volume | Prix/mois |
|-----------|-------|--------|-----------|
| S3 | **Cloudflare R2** | 10 GB free | 0 € |
| OU S3 | **AWS S3** | < 1 GB | ~0.02 € |

**Retenu : Cloudflare R2 → 0 €/mois**

### Error tracking
| Composant | Choix | Prix/mois |
|-----------|-------|-----------|
| Erreurs | **Sentry Free** | 0 € |

### LLM (HR Query Engine)
| Modèle | Volume | Coût estimé |
|--------|--------|-------------|
| Claude Haiku | ~20 requêtes × ~2k tokens input + 500 output | ~0.03 € |

### TOTAL SCÉNARIO A

| Poste | €/mois |
|-------|--------|
| App server (web) | 5 € |
| Job worker | 3 € |
| PostgreSQL | 0 € |
| Redis | 0 € |
| Email | 0 € |
| Stockage | 0 € |
| Error tracking | 0 € |
| LLM (Claude Haiku) | < 1 € |
| **TOTAL** | **~8–10 €/mois** |

> ⚠️ Pas de redondance, pas de backup automatique, pas de SLA. Acceptable pour valider le produit.

---

## SCÉNARIO B — CROISSANCE (50 orgs, ~2 000 employés)

> Prod stable, haute dispo, backups, monitoring correct.

### Compute — Web App
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| App server | **Fly.io** 2× Machines | `shared-cpu-2x` 512 MB × 2 | ~14 € |
| OU App server | **Render** Standard | 512 MB × 2 instances | ~28 € |
| OU App server | **AWS ECS Fargate** | 0.5 vCPU / 1 GB × 2 tasks | ~25 € |

**Retenu : Fly.io 2× shared-cpu-2x → ~14 €/mois**
*(2 instances pour la redondance, WEB_CONCURRENCY=2, 5 threads chacune)*

### Background Jobs
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| Job worker | Fly.io Machine | `performance-1x` 2 GB RAM | ~10 € |

*(15 threads Solid Queue : schedulers × 1 + accruals × 2 + default × 1)*

### Base de données
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| PostgreSQL | **Neon Pro** | 10 GB storage, autoscale compute | ~19 € |
| OU PostgreSQL | **AWS RDS db.t4g.small** | 20 GB SSD, 2 GB RAM | ~28 € |
| OU PostgreSQL | **Supabase Pro** | 8 GB storage, 4 GB RAM | ~25 € |

**Retenu : Neon Pro → ~19 €/mois** (branching pour staging inclus)

### Redis
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| Redis | **Upstash Pay-as-you-go** | ~500k commands/mois | ~2 € |
| OU Redis | **Render Redis** | 256 MB | ~10 € |

**Retenu : Upstash → ~2 €/mois**

### Email transactionnel
| Composant | Choix | Volume | Prix/mois |
|-----------|-------|--------|-----------|
| SMTP | **Resend** Starter | 50 000 emails/mois | ~17 € |
| OU SMTP | **Postmark** | 10 000 emails/mois | ~10 € |
| OU SMTP | **Brevo Starter** | 20 000 emails/mois | ~19 € |

**Retenu : Postmark 10k → ~10 €/mois**

### Stockage fichiers (ActiveStorage)
| Composant | Choix | Volume | Prix/mois |
|-----------|-------|--------|-----------|
| Objet storage | **Cloudflare R2** | ~10 GB + egress gratuit | ~0.15 € |
| OU S3 | **AWS S3** | 10 GB storage + transfers | ~1 € |

**Retenu : Cloudflare R2 → ~0.15 €/mois**

### Error tracking + Monitoring
| Composant | Choix | Prix/mois |
|-----------|-------|-----------|
| Erreurs | **Sentry Team** 1 user | ~22 € |
| OU Erreurs | **Honeybadger** Starter | ~23 € |
| Logs | **Logtail (Better Stack)** Free | 0 € |
| OU Logs | **Papertrail** Developer | ~7 € |

**Retenu : Sentry Team + Logtail → ~22 €/mois**

### Domaine + SSL
| Composant | Prix/an | Prix/mois |
|-----------|---------|-----------|
| Domaine `.com` | ~12 €/an | ~1 € |
| SSL | Inclus Let's Encrypt / Fly.io | 0 € |

### LLM (HR Query Engine)
| Modèle | Volume | Coût estimé |
|--------|--------|-------------|
| Claude Haiku | ~500 req × 2 500 tokens avg | ~0.70 € |

*Tarif Claude Haiku : $0.80/MTok input + $4/MTok output (2026)*

### TOTAL SCÉNARIO B

| Poste | €/mois |
|-------|--------|
| App server (web × 2) | 14 € |
| Job worker | 10 € |
| PostgreSQL (Neon Pro) | 19 € |
| Redis (Upstash) | 2 € |
| Email (Postmark 10k) | 10 € |
| Stockage (R2) | < 1 € |
| Sentry Team | 22 € |
| Logtail | 0 € |
| Domaine | 1 € |
| LLM (Claude Haiku) | 1 € |
| **TOTAL** | **~80 €/mois** |

> ✅ SLA correct, backups automatiques Neon, redondance web basique.

---

## SCÉNARIO C — CIBLE (200 orgs, 10 000 employés)

> Production SaaS mature, haute disponibilité, auto-scaling, observabilité complète.

### Compute — Web App
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| App server | **Fly.io** 4× Machines | `performance-1x` 2 GB RAM × 4 | ~100 € |
| OU App server | **AWS ECS Fargate** | 1 vCPU / 2 GB × 4 tasks | ~130 € |
| OU App server | **Render** Standard | 2 GB × 4 instances | ~112 € |

**Retenu : Fly.io 4× performance-1x → ~100 €/mois**
*(Auto-scaling 2→4 instances selon charge, WEB_CONCURRENCY=2 chacune, 5 threads)*

### Background Jobs
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| Job worker | Fly.io 2× Machines | `performance-2x` 4 GB RAM × 2 | ~60 € |

*(200 orgs × accrual jobs parallèles, ACCRUAL_CONCURRENCY=4)*

### Base de données
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| PostgreSQL principal | **AWS RDS db.t4g.medium** | 4 vCPU / 4 GB RAM / 200 GB SSD, Multi-AZ | ~180 € |
| OU PostgreSQL | **Neon Business** | 10 GB storage + autoscale | ~55 € |
| Read replica | **AWS RDS** | db.t4g.small (lectures lourdes) | ~40 € |

**Retenu : AWS RDS db.t4g.medium Multi-AZ + read replica → ~220 €/mois**

*Justification Multi-AZ : les leave_balances et time_entries sont des données financières-like — aucune perte acceptable.*

### Redis
| Composant | Choix | Spec | Prix/mois |
|-----------|-------|------|-----------|
| Redis | **AWS ElastiCache r7g.large** | 13 GB RAM, cluster mode | ~130 € |
| OU Redis | **Upstash Pro** | 50 GB, multi-region | ~80 € |

**Retenu : Upstash Pro → ~80 €/mois** (plus simple à opérer)

### Email transactionnel
| Composant | Choix | Volume | Prix/mois |
|-----------|-------|--------|-----------|
| SMTP | **Postmark** | 30 000 emails/mois | ~25 € |
| OU SMTP | **Resend** Scale | 100 000 emails/mois | ~75 € |
| OU SMTP | **AWS SES** | 30 000 emails | ~3 € |

**Retenu : AWS SES → ~3 €/mois** (le moins cher à volume, même config que le reste AWS)

### Stockage fichiers (ActiveStorage)
| Composant | Choix | Volume | Prix/mois |
|-----------|-------|--------|-----------|
| Objet storage | **Cloudflare R2** | 100 GB + egress gratuit | ~1.50 € |
| OU S3 | **AWS S3** | 100 GB + transfers | ~7 € |

**Retenu : Cloudflare R2 → ~1.50 €/mois**

### Error tracking + Monitoring + Logs
| Composant | Choix | Prix/mois |
|-----------|-------|-----------|
| Erreurs + APM | **Sentry Business** 5 users | ~87 € |
| OU Erreurs | **Datadog APM** | ~150 € |
| Logs | **Better Stack** (Logtail) Team | ~25 € |
| Uptime monitoring | **Better Stack** Uptime | ~0 € (inclus) |

**Retenu : Sentry Business + Logtail Team → ~112 €/mois**

### Réseau + Sécurité
| Composant | Choix | Prix/mois |
|-----------|-------|-----------|
| CDN + DDoS | **Cloudflare Free/Pro** | 0–18 € |
| Domaine + DNS | — | ~1 € |
| Certificates | Let's Encrypt / Fly.io inclus | 0 € |

**Retenu : Cloudflare Pro → ~18 €/mois** (WAF basique inclus, très recommandé pour un SaaS RH)

### Backups
| Composant | Choix | Prix/mois |
|-----------|-------|-----------|
| DB snapshots | AWS RDS automated (inclus) | 0 € |
| DB backup vers S3 | ~20 GB/snapshot × 7 jours | ~0.50 € |
| OU WAL backup | **Neon** (si retenu) | Inclus |

### LLM (HR Query Engine)
| Modèle | Volume | Coût estimé |
|--------|--------|-------------|
| Claude Haiku 4.5 | ~3 000 req × 2 500 tokens avg | ~4 € |

*$0.80/MTok input + $4/MTok output × 3k requêtes × 2k/500 tokens*

### TOTAL SCÉNARIO C

| Poste | €/mois |
|-------|--------|
| App server (web × 4) | 100 € |
| Job workers (× 2) | 60 € |
| PostgreSQL RDS Multi-AZ | 180 € |
| Read replica RDS | 40 € |
| Redis (Upstash Pro) | 80 € |
| Email (AWS SES) | 3 € |
| Stockage (Cloudflare R2) | 2 € |
| Sentry Business | 87 € |
| Logtail Team (logs) | 25 € |
| Cloudflare Pro (CDN/WAF) | 18 € |
| Domaine | 1 € |
| LLM (Claude Haiku) | 4 € |
| Divers (egress, transfers) | ~10 € |
| **TOTAL** | **~610 €/mois** |

> ✅ Haute dispo, Multi-AZ, auto-scaling, observabilité complète, SLA 99.9%.

---

## TABLEAU COMPARATIF

| Poste | Lancement | Croissance | Cible |
|-------|-----------|------------|-------|
| Orgs / Employés | 5–10 / 200 | 50 / 2 000 | 200 / 10 000 |
| **Web (compute)** | 5 € | 14 € | 100 € |
| **Jobs (Solid Queue)** | 3 € | 10 € | 60 € |
| **PostgreSQL** | 0 € | 19 € | 220 € |
| **Redis** | 0 € | 2 € | 80 € |
| **Email** | 0 € | 10 € | 3 € |
| **Stockage** | 0 € | < 1 € | 2 € |
| **Monitoring** | 0 € | 22 € | 112 € |
| **CDN/Réseau** | 0 € | 1 € | 19 € |
| **LLM** | < 1 € | 1 € | 4 € |
| **TOTAL** | **~8 €** | **~80 €** | **~610 €** |
| **Par org/mois** | ~1 € | ~1.60 € | **~3 €** |
| **Par employé/mois** | ~0.04 € | ~0.04 € | **~0.06 €** |

---

## COÛT LLM — DÉTAIL CLAUDE HAIKU

Le HR Query Engine appelle Claude Haiku à chaque requête NL-to-Filters.

| Paramètre | Valeur |
|-----------|--------|
| Modèle | `claude-haiku-4-5-20251001` |
| Input moyen/requête | ~2 000 tokens (system prompt + question) |
| Output moyen/requête | ~500 tokens (JSON filtres) |
| Prix input | $0.80 / MTok |
| Prix output | $4.00 / MTok |
| **Coût par requête** | **~$0.0036** (~0.003 €) |

| Volume requêtes/mois | Coût LLM/mois |
|----------------------|---------------|
| 100 | ~0.34 € |
| 500 | ~1.70 € |
| 1 000 | ~3.40 € |
| 3 000 | ~10 € |
| 10 000 | ~34 € |

> Le LLM reste **négligeable** dans le budget total même à forte utilisation.

---

## RECOMMANDATIONS PAR ÉTAPE

### Lancement (J0)
- Fly.io pour tout (web + jobs) — déploiement en 30 min, prix minimal
- Neon Free pour la DB (upgrade trivial vers Pro)
- Upstash Free pour Redis
- Resend Free pour les emails
- Cloudflare R2 pour les fichiers (migration depuis local triviale)
- **Budget : ~10 €/mois**

### 6 mois (Première croissance)
- Upgrader Neon → Pro (~19 €)
- Activer Sentry Team (~22 €) — obligatoire pour la prod réelle
- Passer Upstash Pay-as-you-go (~2 €)
- Activer Postmark pour les emails transactionnels (déliverabilité > Resend)
- **Budget : ~80 €/mois**

### 18 mois (Scale SaaS)
- Migrer DB vers RDS Multi-AZ (disponibilité financière des données RH)
- 4 instances web avec auto-scaling
- Cloudflare Pro pour le WAF
- Sentry Business avec APM
- **Budget : ~610 €/mois**

---

## COÛT PAR CLIENT (Économie unitaire)

À la cible (200 orgs, 610 €/mois infra) :

| Tarif SaaS mensuel/org | Marge infra | Ratio infra/CA |
|------------------------|-------------|----------------|
| 50 €/org/mois (10k€ CA) | 9 400 € | 6.1% |
| 100 €/org/mois (20k€ CA) | 19 400 € | 3.1% |
| 200 €/org/mois (40k€ CA) | 39 400 € | 1.5% |

> L'infra représente moins de 6% du CA même au tarif le plus bas. Les coûts dominants sont les ressources humaines, pas l'infrastructure.

---

## SERVICES TIERS NON INCLUS

Ces coûts sont hors scope infra mais à prévoir :

| Service | Usage | Prix estimé |
|---------|-------|-------------|
| GitHub / GitLab | CI/CD, repos | 0–19 €/mois |
| GitHub Actions | CI (tests, lint, deploy) | 0–8 €/mois |
| Calendrier (Google/MS) | Intégration webhook | 0 € (API gratuite) |
| Stripe | Paiements SaaS | 1.4% + 0.25€/transaction |
| Support (Intercom/Crisp) | Customer support | 25–95 €/mois |
| Legal / DPO (RGPD) | Compliance | Variable |

---

*Dernière mise à jour : 2026-02-27 par @architect*
*Tarifs vérifiés sur les pages publiques des fournisseurs — sujets à variation.*
