# FEATURE INVENTORY — EASY-RH

**Date** : 2026-02-27
**Source** : Audit exhaustif du codebase par @architect
**Usage** : Base pour le pricing, feature flags, roadmap produit

---

## DOMAINES FONCTIONNELS

### 1. GESTION DU TEMPS (Time Tracking)
**Techniquement** : `TimeEntriesController`, `TimeEntry` model, `RttAccrualService`, `TimeEntriesController` API

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Pointage clock in / clock out (web) | Employé (non-cadre) | — | — |
| Pointage via API mobile (JWT) | Employé (non-cadre) | — | — |
| Géolocalisation au pointage (lat/long/accuracy) | Employé | — | — |
| Détection de retard (> 5 min vs horaire) | Système auto | — | — |
| Validation des pointages par le manager | Manager | — | — |
| Rejet des pointages avec motif | Manager | — | — |
| Rappel hebdomadaire de validation (email) | Manager | — | — |
| Historique des pointages (vue employé) | Employé | — | — |
| Vue équipe des pointages | Manager | — | — |
| Export CSV des pointages équipe | Manager | ✅ | — |
| Calcul automatique RTT à partir des heures sup | Système auto (job) | — | — |
| Limite légale 10h/jour (Code du travail) | Système auto | — | — |
| Flag cadre (désactivation pointage par employé) | Admin/HR | — | — |

---

### 2. GESTION DES CONGÉS (Leave Management)
**Techniquement** : `LeaveRequestsController`, `LeaveBalancesController`, `LeavePolicyEngine`, `LeaveAccrualDispatcherJob`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Demande de congé (CP, RTT, Maladie, Parental, Sans solde) | Employé | — | — |
| Support demi-journée (début / fin) | Employé | — | — |
| Approbation / Rejet par le manager | Manager | — | — |
| Auto-approbation configurable (par rôle, par type) | HR/Admin | — | — |
| Calcul automatique solde CP (2.5j/mois, max 30j/an) | Système auto (job mensuel) | — | — |
| Calcul automatique RTT (heures > 35h → jours) | Système auto (job hebdo) | — | — |
| Expiration CP (31 mai par défaut, configurable) | Système auto | — | — |
| Règle 10 jours consécutifs été (Code du travail) | Système auto | — | — |
| Détection conflits équipe (sur-absence) | Système auto | — | — |
| Calendrier équipe des absences | Manager/Employé | — | — |
| Vue des demandes en attente d'approbation | Manager | — | — |
| Notifications email (soumis / approuvé / rejeté / annulé) | Auto (mailer) | — | — |
| Soldes en temps réel par type | Employé | — | — |
| Ajustement temps partiel (ratio proratisé) | Système auto | — | — |
| Export CSV absences équipe | Manager | ✅ | — |

---

### 3. PLANIFICATION (Scheduling)
**Techniquement** : `WorkSchedule`, `WeeklySchedulePlan`, `TeamSchedulesController`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Horaire hebdomadaire par employé (pattern JSONB) | Manager | — | — |
| Templates prédéfinis (35h, 39h+RTT, 24h mi-temps) | Manager | — | — |
| Vue planning équipe (semaine) | Manager | — | — |
| Override hebdomadaire du planning (WeeklySchedulePlan) | Manager | — | — |
| Calcul automatique RTT eligibility (> 35h) | Système | — | — |
| Validation légale max 48h/semaine | Système | — | — |

---

### 4. PERFORMANCE (Objectifs, 1:1, Évaluations)
**Techniquement** : `Objective`, `OneOnOne`, `ActionItem`, `Evaluation`, `EvaluationBuilder`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Création d'objectifs (titre, priorité, deadline) | Manager → Employé | — | — |
| Suivi statut objectifs (draft/en_cours/complété/bloqué) | Employé + Manager | — | — |
| Planification de 1:1 (agenda, notes, date) | Manager | — | — |
| Action items issus des 1:1 (avec deadline) | Manager + Employé | — | — |
| Complétion des action items | Employé | — | — |
| Évaluations multi-étapes (auto-éval → éval manager) | Employé + Manager | — | — |
| Score d'évaluation 1-5 avec critères pondérés | Manager | — | — |
| Lancement d'évaluation par période | HR/Admin | — | — |
| Lien évaluation ↔ objectifs | Manager | — | — |
| Lien évaluation ↔ formations recommandées | Manager | — | — |
| Intégration calendrier externe (webhook 1:1) | Système auto | — | — |
| Export CSV des 1:1 | Manager | ✅ | — |
| Export CSV des évaluations | Manager | ✅ | — |

---

### 5. FORMATIONS (Trainings)
**Techniquement** : `Training`, `TrainingAssignment`, `TrainingTracker`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Catalogue formations (interne, externe, certif, e-learning, mentorat) | Manager | — | — |
| Assignation d'une formation à un employé | Manager | — | — |
| Suivi de progression (pending/en_cours/complété) | Employé + Manager | — | — |
| Date limite de complétion | Manager | — | — |
| Archive/désarchive des formations | Manager | — | — |
| Lien formation ↔ évaluation | Manager | — | — |
| Export CSV des formations | Manager | ✅ | — |

---

### 6. ONBOARDING
**Techniquement** : `EmployeeOnboarding`, `OnboardingTemplate`, `OnboardingTask`, `OnboardingReview`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Templates d'onboarding réutilisables | HR/Admin | — | — |
| Tâches par rôle (employé/manager/HR/admin) | HR/Admin | — | — |
| Création d'onboarding depuis template | Manager | — | — |
| Suivi progression % (cache calculé) | Manager + Employé | — | — |
| Score d'intégration (qualitatif, 0-100) | Manager + HR | — | — |
| Revues périodiques avec feedback | Manager | — | — |
| Vue employé de sa progression | Employé | — | — |
| Statuts (actif / complété / annulé) | Manager + HR | — | — |
| Contrainte 1 seul onboarding actif par employé | Système | — | — |

---

### 7. PAIE & ANALYTICS RH (Payroll)
**Techniquement** : `PayrollController`, `PayrollCsvExporter`, `EmployeePolicy#see_salary?`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Dashboard masse salariale (brut mensuel, coût employeur) | HR/Admin | — | — |
| Effectif total et salaire brut moyen | HR/Admin | — | — |
| Projection annuelle de la masse salariale | HR/Admin | — | — |
| Répartition par type de contrat | HR/Admin | — | — |
| Répartition par département | HR/Admin | — | — |
| Tranches salariales (5 niveaux) | HR/Admin | — | — |
| Cadre vs non-cadre | HR/Admin | — | — |
| Analyse ancienneté × salaire | HR/Admin | — | — |
| Estimation coût congés (jours × taux journalier) | HR/Admin | — | — |
| Top 10 des rémunérations | HR/Admin | — | — |
| Export CSV masse salariale | HR/Admin | ✅ | — |
| Confidentialité salariale (seul HR/Admin voit) | Système (Pundit) | — | — |

---

### 8. HR QUERY ENGINE (IA)
**Techniquement** : `HrQueryInterpreterService`, `HrQueryExecutorService`, `PromptBuilder`, Claude Haiku

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Requête en langage naturel français | HR/Admin | — | ✅ |
| Filtres structurés (dept, rôle, contrat, ancienneté, salaire, congés, onboarding) | HR/Admin | — | ✅ |
| Résultats tabulaires dans le navigateur | HR/Admin | — | — |
| Export CSV des résultats de requête | HR/Admin | ✅ | — |
| Isolation tenant (organisation_id jamais dans les filtres LLM) | Système | — | — |
| Garde salariale server-side (re-validée indépendamment du LLM) | Système | — | — |
| Rate limiting dédié (20 req / 5 min / user) | Système | — | — |

---

### 9. ADMINISTRATION (Admin Panel)
**Techniquement** : `Admin::*` controllers, `GroupPoliciesController`, `AuditLogsController`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| CRUD employés (création, édition, archivage) | HR/Admin | — | — |
| Paramètres organisation (heures/semaine, RTT, taux CP) | HR/Admin | — | — |
| Configuration règles RH par groupe (Group Policies) | HR/Admin | — | — |
| Prévisualisation des règles avant sauvegarde | HR/Admin | — | — |
| Journal d'audit (LeaveRequest, EmployeeOnboarding) | HR/Admin | — | — |
| Templates d'onboarding (CRUD + tâches) | HR/Admin | — | — |

---

### 10. PROFIL & DASHBOARD
**Techniquement** : `ProfileController`, `DashboardController`, cards system

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Profil employé (infos personnelles, avatar) | Employé | — | — |
| Dashboard personnalisé (cards par rôle) | Tous | — | — |
| Personnalisation ordre et visibilité des cards | Tous | — | — |
| Centre de notifications in-app | Tous | — | — |
| Marquer notifications lues / tout marquer | Tous | — | — |

---

### 11. API MOBILE (JWT)
**Techniquement** : `Api::V1::*` controllers, `devise-jwt`, `JwtDenylist`

| Feature | Rôle | Export CSV | LLM |
|---------|------|-----------|-----|
| Authentification JWT (login / logout / refresh) | Tous | — | — |
| Dashboard mobile (résumé) | Employé | — | — |
| Pointage mobile (clock in / out) | Employé | — | — |
| Consultation demandes de congé | Employé | — | — |
| Soumission demande de congé | Employé | — | — |
| Approbation / rejet congé (manager) | Manager | — | — |
| Consultation soldes | Employé | — | — |
| Consultation / mise à jour planning | Employé | — | — |
| Vue équipe (manager) | Manager | — | — |

---

## STATISTIQUES TECHNIQUES

| Métrique | Valeur |
|----------|--------|
| Contrôleurs | 42 |
| Modèles domaine | 25+ |
| Jobs background | 11 |
| Mailers | 2 |
| Policies Pundit | 22 |
| Exporteurs CSV | 7 |
| Tables DB | 39 |
| Endpoints API | 16 |
| Rôles utilisateur | 4 (employee, manager, hr, admin) |
| Types de congés | 5 (CP, RTT, Maladie, Parental, Sans solde) |

---

## FEATURES TECHNIQUEMENT LIMITABLES PAR TIER

Ces features peuvent être gateées par un simple attribut sur `Organization` (`plan` ou `features` JSONB) :

| Feature | Mécanisme de limitation |
|---------|------------------------|
| Nombre d'employés max | `Organization#employee_count <= plan_limit` |
| Onboarding | `organization.feature_enabled?(:onboarding)` |
| Performance (OKR + 1:1 + évals) | `organization.feature_enabled?(:performance)` |
| Formations | `organization.feature_enabled?(:trainings)` |
| HR Query Engine (IA) | `organization.feature_enabled?(:hr_query)` |
| Export CSV | `organization.feature_enabled?(:csv_exports)` |
| Payroll dashboard | `organization.feature_enabled?(:payroll)` |
| API mobile | `organization.feature_enabled?(:mobile_api)` |
| Audit logs | `organization.feature_enabled?(:audit_logs)` |
| Intégration calendrier | `organization.feature_enabled?(:calendar_integration)` |
| Quota requêtes LLM | `organization.monthly_llm_quota` |

---

*Dernière mise à jour : 2026-02-27 par @architect*
