# PRICING TIERS & FEATURE FLAGS — EASY-RH

**Date** : 2026-02-27
**Auteur** : @architect
**Base** : FEATURE_INVENTORY.md + INFRASTRUCTURE_COSTS.md

> Ce document couvre deux choses :
> 1. La proposition de tiers produit (ce qui va dans chaque plan)
> 2. L'implémentation technique des feature flags (comment le coder)

---

## PARTIE 1 — TIERS PRODUIT

### Philosophie de découpage

**Principe** : Le cœur (temps + congés + planning) est inclus partout — c'est le minimum viable pour un SIRH français.
La valeur premium vient des modules RH avancés (performance, onboarding, IA) et de la taille de l'équipe.

**Modèle de pricing** : `prix fixe/mois + prix par employé/mois`
- Évite le frein à l'adoption (pas de "prix prohibitif dès le 1er employé")
- Scale naturellement avec la valeur perçue

---

### TIER 1 — ESSENTIEL

**Cible** : PME < 20 employés, premier SIRH, budget serré

```
Prix : 49 €/mois (jusqu'à 10 employés)
       + 4 €/employé/mois au-delà
```

**Inclus** :

#### Gestion du temps
- ✅ Pointage clock in / clock out (web)
- ✅ Historique des pointages
- ✅ Validation manager
- ✅ Calcul RTT automatique
- ✅ Rappels de validation par email
- ❌ Géolocalisation (GPS)
- ❌ API mobile

#### Congés
- ✅ CP, RTT, Maladie, Sans solde
- ✅ Approbation / rejet manager
- ✅ Calcul automatique des soldes (CP 2.5j/mois)
- ✅ Notifications email (soumis / approuvé / rejeté)
- ✅ Calendrier équipe
- ❌ Congé parental
- ❌ Auto-approbation configurable
- ❌ Règles d'entreprise personnalisées (Group Policies)

#### Planning
- ✅ Horaire hebdomadaire par employé
- ✅ Templates (35h, 39h, mi-temps)
- ✅ Vue planning équipe
- ❌ Override hebdomadaire (WeeklySchedulePlan)

#### Administration
- ✅ Gestion des employés (CRUD)
- ✅ Paramètres organisation de base
- ✅ Dashboard par rôle
- ✅ Profil employé
- ✅ Notifications in-app

#### Exports
- ✅ Export CSV absences
- ✅ Export CSV pointages

#### Limites
- Max **25 employés**
- Max **1 template d'onboarding** (lecture seule, template par défaut)
- Support : email uniquement (48h)

---

### TIER 2 — PRO

**Cible** : PME/ETI 20–100 employés, RH structurée, besoin de suivi de la performance

```
Prix : 149 €/mois (jusqu'à 20 employés)
       + 6 €/employé/mois au-delà
```

**Tout ce qui est dans Essentiel, plus** :

#### Congés (avancé)
- ✅ Congé parental
- ✅ Auto-approbation configurable par rôle et par type
- ✅ Group Policies (règles RH personnalisées par groupe)
- ✅ Prévisualisation des règles avant sauvegarde

#### Planning (avancé)
- ✅ Override hebdomadaire du planning
- ✅ Gestion temps partiel avec ratio proratisé

#### Performance (module complet)
- ✅ Objectifs (OKR) — création, suivi, priorité, deadline
- ✅ 1:1 — planification, agenda, notes
- ✅ Action items issus des 1:1
- ✅ Évaluations multi-étapes (auto-éval → éval manager)
- ✅ Score d'évaluation avec critères pondérés
- ✅ Lien évaluation ↔ objectifs
- ✅ Export CSV 1:1 et évaluations

#### Formations
- ✅ Catalogue de formations (interne, externe, e-learning)
- ✅ Assignation et suivi de complétion
- ✅ Lien formation ↔ évaluation
- ✅ Export CSV formations

#### Onboarding
- ✅ Templates d'onboarding illimités
- ✅ Tâches par rôle (employé/manager/HR/admin)
- ✅ Suivi progression % et score d'intégration
- ✅ Revues périodiques avec feedback

#### API Mobile
- ✅ Authentification JWT
- ✅ Pointage mobile
- ✅ Congés mobile (consultation + soumission)
- ✅ Dashboard mobile

#### Administration (avancé)
- ✅ Journal d'audit (LeaveRequest, EmployeeOnboarding)
- ✅ Flag cadre (désactiver pointage par employé)

#### Limites
- Max **100 employés**
- ❌ Dashboard paie / masse salariale
- ❌ HR Query Engine (IA)
- ❌ Intégration calendrier externe
- Support : email (24h) + chat

---

### TIER 3 — ENTREPRISE

**Cible** : ETI 100–500 employés, DRH, besoin d'analytics et d'IA

```
Prix : 499 €/mois (jusqu'à 100 employés)
       + 8 €/employé/mois au-delà
```

**Tout ce qui est dans Pro, plus** :

#### Paie & Analytics RH
- ✅ Dashboard masse salariale (brut mensuel, coût employeur)
- ✅ Projection annuelle
- ✅ Répartition par département, contrat, tranche salariale
- ✅ Analyse ancienneté × salaire
- ✅ Estimation coût congés
- ✅ Top 10 des rémunérations
- ✅ Export CSV masse salariale
- ✅ Confidentialité salariale (seuls HR/Admin voient)

#### HR Query Engine (IA — Claude Haiku)
- ✅ Requêtes en langage naturel français
- ✅ Filtres sur tous les champs (dept, contrat, salaire, ancienneté, congés, onboarding)
- ✅ Résultats tabulaires
- ✅ Export CSV des résultats
- ✅ **50 requêtes IA/mois** incluses
- ➕ Requêtes supplémentaires : 0.10 €/requête

#### Intégrations
- ✅ Intégration calendrier externe (Google Calendar / Outlook via webhook)
- ✅ Géolocalisation au pointage (GPS)

#### API Mobile complète
- ✅ Tout le tier Pro
- ✅ Vue équipe manager (mobile)
- ✅ Approbation congés mobile

#### Limites
- Max **500 employés**
- HR Query : 50 requêtes/mois (puis 0.10 €/requête)
- Support : email (4h) + chat + onboarding dédié

---

### TIER 4 — GRAND COMPTE (sur devis)

**Cible** : > 500 employés, groupes multi-entités, exigences de conformité RGPD poussées

```
Prix : sur devis
       Base : ~1 500 €/mois
       + 5–7 €/employé/mois (volume)
```

**Tout ce qui est dans Entreprise, plus** :

- ✅ Employés illimités
- ✅ HR Query : requêtes illimitées
- ✅ SLA contractuel (99.9% uptime garanti)
- ✅ Instance dédiée (isolation complète de l'infrastructure)
- ✅ SSO (SAML 2.0 / OIDC) — *à développer*
- ✅ Import CSV en masse (employés, balances) — *à développer*
- ✅ Webhook sortant (events RH vers votre SI) — *à développer*
- ✅ DPO dédié / accompagnement RGPD
- ✅ Customer Success Manager dédié
- ✅ Support téléphonique prioritaire (2h)
- ✅ Audit de sécurité annuel

---

## TABLEAU COMPARATIF

| Feature | Essentiel | Pro | Entreprise | Grand Compte |
|---------|-----------|-----|------------|-------------|
| **Prix de base** | 49 €/mois | 149 €/mois | 499 €/mois | Sur devis |
| **Prix/employé sup.** | +4 € | +6 € | +8 € | ~5-7 € |
| **Employés max** | 25 | 100 | 500 | Illimité |
| **Pointage web** | ✅ | ✅ | ✅ | ✅ |
| **Géolocalisation** | ❌ | ❌ | ✅ | ✅ |
| **API mobile** | ❌ | ✅ | ✅ | ✅ |
| **Congés (base)** | ✅ | ✅ | ✅ | ✅ |
| **Congé parental** | ❌ | ✅ | ✅ | ✅ |
| **Group Policies** | ❌ | ✅ | ✅ | ✅ |
| **Planning** | ✅ | ✅ | ✅ | ✅ |
| **Override hebdo** | ❌ | ✅ | ✅ | ✅ |
| **Objectifs / OKR** | ❌ | ✅ | ✅ | ✅ |
| **1:1** | ❌ | ✅ | ✅ | ✅ |
| **Évaluations** | ❌ | ✅ | ✅ | ✅ |
| **Formations** | ❌ | ✅ | ✅ | ✅ |
| **Onboarding** | ❌ | ✅ | ✅ | ✅ |
| **Exports CSV** | ✅ (2) | ✅ (5) | ✅ (7) | ✅ |
| **Paie & Analytics** | ❌ | ❌ | ✅ | ✅ |
| **HR Query (IA)** | ❌ | ❌ | ✅ (50/mois) | ✅ illimité |
| **Audit logs** | ❌ | ✅ | ✅ | ✅ |
| **Intégr. calendrier** | ❌ | ❌ | ✅ | ✅ |
| **SSO (SAML/OIDC)** | ❌ | ❌ | ❌ | ✅ |
| **SLA contractuel** | ❌ | ❌ | ❌ | ✅ |
| **Support** | Email 48h | Email 24h + chat | Email 4h + chat | Tél. 2h + CSM |

---

## SIMULATION DE REVENU

### Scénario conservateur (12 mois post-lancement)

| Tier | Clients | Employés moy. | MRR estimé |
|------|---------|---------------|------------|
| Essentiel | 15 | 12 | 15 × (49 + 2×4) = **855 €** |
| Pro | 8 | 40 | 8 × (149 + 20×6) = **2 152 €** |
| Entreprise | 2 | 150 | 2 × (499 + 50×8) = **1 798 €** |
| **Total** | **25 clients** | | **~4 800 €/mois** |

### Scénario cible (24 mois)

| Tier | Clients | Employés moy. | MRR estimé |
|------|---------|---------------|------------|
| Essentiel | 60 | 15 | 60 × (49 + 5×4) = **4 140 €** |
| Pro | 40 | 60 | 40 × (149 + 40×6) = **15 560 €** |
| Entreprise | 15 | 200 | 15 × (499 + 100×8) = **19 485 €** |
| Grand Compte | 3 | 700 | 3 × 1 500 = **4 500 €** |
| **Total** | **118 clients** | | **~43 700 €/mois** |

**Ratio infra/MRR à la cible** : 610 € / 43 700 € = **1.4%** — très sain.

---

## PARTIE 2 — IMPLÉMENTATION TECHNIQUE DES FEATURE FLAGS

### Approche retenue : attribut `plan` + colonne JSONB `features` sur `Organization`

**Principe** : Simple, sans dépendance externe, cohérent avec l'architecture existante.

Pas de Flipper, Unleash ou LaunchDarkly dans un premier temps — la complexité ne le justifie pas.

---

### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_plan_to_organizations.rb
class AddPlanToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :plan, :string, null: false, default: 'essential'
    add_column :organizations, :plan_employee_limit, :integer, null: false, default: 25
    add_column :organizations, :plan_llm_quota, :integer, null: false, default: 0
    add_column :organizations, :plan_llm_used_this_month, :integer, null: false, default: 0
    add_column :organizations, :plan_features, :jsonb, null: false, default: {}
    add_column :organizations, :plan_expires_at, :datetime

    add_index :organizations, :plan
  end
end
```

---

### Organization model

```ruby
# app/models/organization.rb
class Organization < ApplicationRecord
  # Plans disponibles
  PLANS = %w[essential pro enterprise enterprise_plus].freeze

  # Features par plan (source de vérité)
  PLAN_FEATURES = {
    'essential' => %w[
      time_tracking leave_management scheduling
      csv_exports_basic notifications dashboard
    ],
    'pro' => %w[
      time_tracking leave_management scheduling
      csv_exports_full notifications dashboard
      parental_leave group_policies schedule_overrides
      performance trainings onboarding
      mobile_api audit_logs
    ],
    'enterprise' => %w[
      time_tracking leave_management scheduling
      csv_exports_full notifications dashboard
      parental_leave group_policies schedule_overrides
      performance trainings onboarding
      mobile_api audit_logs
      geolocation payroll hr_query calendar_integration
    ],
    'enterprise_plus' => :all  # Tout, sans limites
  }.freeze

  PLAN_EMPLOYEE_LIMITS = {
    'essential'      => 25,
    'pro'            => 100,
    'enterprise'     => 500,
    'enterprise_plus' => Float::INFINITY
  }.freeze

  PLAN_LLM_QUOTAS = {
    'essential'       => 0,
    'pro'             => 0,
    'enterprise'      => 50,
    'enterprise_plus' => Float::INFINITY
  }.freeze

  validates :plan, inclusion: { in: PLANS }

  # Vérifie si une feature est activée pour cette organisation
  def feature_enabled?(feature)
    return true if plan == 'enterprise_plus'

    allowed = PLAN_FEATURES[plan]
    return false unless allowed

    allowed.include?(feature.to_s) || plan_features[feature.to_s] == true
  end

  # Vérifie si la limite d'employés est atteinte
  def within_employee_limit?
    limit = plan_employee_limit || PLAN_EMPLOYEE_LIMITS[plan]
    return true if limit == Float::INFINITY
    employees.active.count < limit
  end

  # Vérifie si le quota LLM est disponible
  def llm_quota_available?
    return false unless feature_enabled?(:hr_query)
    return true if plan == 'enterprise_plus'
    plan_llm_used_this_month < (plan_llm_quota || PLAN_LLM_QUOTAS[plan])
  end

  def increment_llm_usage!
    increment!(:plan_llm_used_this_month)
  end
end
```

---

### Concern `PlanGated` pour les controllers

```ruby
# app/controllers/concerns/plan_gated.rb
module PlanGated
  extend ActiveSupport::Concern

  private

  def require_feature!(feature)
    return if current_organization.feature_enabled?(feature)

    respond_to do |format|
      format.html do
        redirect_to dashboard_path,
          alert: "Cette fonctionnalité n'est pas incluse dans votre plan. " \
                 "Passez à un plan supérieur pour y accéder."
      end
      format.json do
        render json: { error: 'feature_not_available', feature: feature }, status: :payment_required
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('flash',
          partial: 'shared/flash_messages',
          locals: { alert: "Fonctionnalité non disponible dans votre plan." })
      end
    end
  end

  def require_llm_quota!
    return if current_organization.llm_quota_available?

    redirect_to admin_hr_query_path,
      alert: "Quota de requêtes IA atteint pour ce mois. " \
             "Passez au plan Entreprise+ ou attendez le 1er du mois."
  end
end
```

---

### Utilisation dans les controllers

```ruby
# app/controllers/manager/evaluations_controller.rb
class Manager::EvaluationsController < Manager::BaseController
  include PlanGated
  before_action -> { require_feature!(:performance) }
  # ...
end

# app/controllers/manager/trainings_controller.rb
class Manager::TrainingsController < Manager::BaseController
  include PlanGated
  before_action -> { require_feature!(:trainings) }
  # ...
end

# app/controllers/manager/employee_onboardings_controller.rb
class Manager::EmployeeOnboardingsController < Manager::BaseController
  include PlanGated
  before_action -> { require_feature!(:onboarding) }
  # ...
end

# app/controllers/admin/hr_queries_controller.rb
class Admin::HrQueriesController < Admin::BaseController
  include PlanGated
  before_action -> { require_feature!(:hr_query) }
  before_action :require_llm_quota!, only: [:create]

  def create
    # ... interprétation LLM ...
    current_organization.increment_llm_usage!
  end
end

# app/controllers/admin/payroll_controller.rb
class Admin::PayrollController < Admin::BaseController
  include PlanGated
  before_action -> { require_feature!(:payroll) }
  # ...
end
```

---

### Vérification dans les vues (navigation conditionnelle)

```erb
<%# app/views/layouts/manager.html.erb %>

<% if current_organization.feature_enabled?(:performance) %>
  <%= link_to "Objectifs", manager_objectives_path, class: nav_class('objectives') %>
  <%= link_to "1:1", manager_one_on_ones_path, class: nav_class('one_on_ones') %>
  <%= link_to "Évaluations", manager_evaluations_path, class: nav_class('evaluations') %>
<% end %>

<% if current_organization.feature_enabled?(:trainings) %>
  <%= link_to "Formations", manager_trainings_path, class: nav_class('trainings') %>
<% end %>

<% if current_organization.feature_enabled?(:onboarding) %>
  <%= link_to "Onboarding", manager_employee_onboardings_path, class: nav_class('employee_onboardings') %>
<% end %>
```

---

### Vérification dans les Pundit policies

```ruby
# app/policies/evaluation_policy.rb
class EvaluationPolicy < ApplicationPolicy
  def index?
    user.organization.feature_enabled?(:performance) && (
      user.manager_or_above? || record_scope_includes_user?
    )
  end
  # ...
end

# app/policies/hr_query_policy.rb
class HrQueryPolicy < ApplicationPolicy
  def show?
    user.organization.feature_enabled?(:hr_query) && user.hr_or_admin?
  end

  def create?
    show? && user.organization.llm_quota_available?
  end
end
```

---

### Job de reset mensuel du quota LLM

```ruby
# app/jobs/reset_llm_quota_job.rb
class ResetLlmQuotaJob < ApplicationJob
  queue_as :schedulers

  def perform
    Organization.where.not(plan: 'essential')
                .update_all(plan_llm_used_this_month: 0)
    Rails.logger.info "[ResetLlmQuotaJob] LLM quotas reset for all organizations"
  end
end
```

```yaml
# config/recurring.yml (ajouter)
reset_llm_quotas:
  class: ResetLlmQuotaJob
  schedule: "0 0 1 * *"   # 1er du mois à minuit
  queue: schedulers
```

---

### Vérification de la limite d'employés

```ruby
# app/controllers/admin/employees_controller.rb
class Admin::EmployeesController < Admin::BaseController
  before_action :check_employee_limit, only: [:new, :create]

  private

  def check_employee_limit
    return if current_organization.within_employee_limit?

    redirect_to admin_employees_path,
      alert: "Limite de #{current_organization.plan_employee_limit} employés atteinte " \
             "pour votre plan. Passez à un plan supérieur pour ajouter des employés."
  end
end
```

---

### Seeds et factories

```ruby
# db/seeds.rb (ajouter)
Organization.find_each do |org|
  org.update!(
    plan: 'enterprise',
    plan_employee_limit: 500,
    plan_llm_quota: 50
  ) unless org.plan.present?
end

# spec/factories/organizations.rb (ajouter traits)
factory :organization do
  # ...

  trait :essential_plan do
    plan { 'essential' }
    plan_employee_limit { 25 }
    plan_llm_quota { 0 }
  end

  trait :pro_plan do
    plan { 'pro' }
    plan_employee_limit { 100 }
    plan_llm_quota { 0 }
  end

  trait :enterprise_plan do
    plan { 'enterprise' }
    plan_employee_limit { 500 }
    plan_llm_quota { 50 }
  end
end
```

---

### Tests des feature flags

```ruby
# spec/models/organization_spec.rb (ajouter)
describe '#feature_enabled?' do
  context 'plan essentiel' do
    let(:org) { build(:organization, :essential_plan) }

    it 'autorise time_tracking' do
      expect(org.feature_enabled?(:time_tracking)).to be true
    end

    it 'refuse performance' do
      expect(org.feature_enabled?(:performance)).to be false
    end

    it 'refuse hr_query' do
      expect(org.feature_enabled?(:hr_query)).to be false
    end
  end

  context 'plan enterprise_plus' do
    let(:org) { build(:organization, plan: 'enterprise_plus') }

    it 'autorise tout' do
      expect(org.feature_enabled?(:hr_query)).to be true
      expect(org.feature_enabled?(:anything)).to be true
    end
  end
end

describe '#llm_quota_available?' do
  let(:org) { create(:organization, :enterprise_plan, plan_llm_quota: 50) }

  it 'est disponible si quota non atteint' do
    org.update!(plan_llm_used_this_month: 49)
    expect(org.llm_quota_available?).to be true
  end

  it 'est indisponible si quota atteint' do
    org.update!(plan_llm_used_this_month: 50)
    expect(org.llm_quota_available?).to be false
  end
end
```

---

## RÉCAPITULATIF DE L'IMPLÉMENTATION

### Ce qu'il faut créer
- [ ] Migration `add_plan_to_organizations`
- [ ] Constantes `PLAN_FEATURES` / `PLAN_EMPLOYEE_LIMITS` / `PLAN_LLM_QUOTAS` dans `Organization`
- [ ] Méthodes `feature_enabled?`, `within_employee_limit?`, `llm_quota_available?`
- [ ] Concern `PlanGated` avec `require_feature!` et `require_llm_quota!`
- [ ] `before_action` sur les controllers concernés (7 controllers)
- [ ] Guards dans les vues de navigation (layouts manager + admin)
- [ ] Guards dans les Pundit policies concernées (EvaluationPolicy, HrQueryPolicy, etc.)
- [ ] Job `ResetLlmQuotaJob` + entrée dans `recurring.yml`
- [ ] Guard dans `EmployeesController#create` pour la limite de seats
- [ ] Tests sur `Organization` (feature_enabled?, quota)
- [ ] Traits FactoryBot `:essential_plan`, `:pro_plan`, `:enterprise_plan`
- [ ] Page "upgrade" ou modale expliquant le plan supérieur (UX)

### Effort estimé
- Migration + modèle + concern : **2h**
- Before actions controllers (7) : **1h**
- Guards vues navigation : **1h**
- Guards policies : **1h**
- Job reset quota + recurring : **0.5h**
- Tests : **2h**
- **Total : ~7-8h**

---

*Dernière mise à jour : 2026-02-27 par @architect*
