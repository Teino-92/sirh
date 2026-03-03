# PAYROLL INTEGRATION ROADMAP — Easy-RH → Silae / ADP

**Date** : 2026-02-28
**Objectif** : Porter l'app de 60/100 à 100/100 de readiness pour une intégration paie (Silae, ADP, PayFit, Sage)
**Estimation totale** : ~3 sprints (6 semaines)

---

## SCORE ACTUEL : 60/100

| Domaine | Score | Statut |
|---------|-------|--------|
| Données employé administratives | 30/50 | ❌ Incomplet |
| Données temps de travail | 40/50 | ⚠️ Partiel |
| Données congés/absences | 45/50 | ✅ Presque |
| Export / API sortante | 10/50 | ❌ Absent |
| Logique de calcul brut | 0/50 | ❌ Absent |

---

## SPRINT 1 — Données administratives employé (semaines 1-2)

### Objectif
Compléter le modèle `Employee` avec les champs obligatoires DSN (Déclaration Sociale Nominative).
Sans ces champs, aucune intégration Silae/ADP n'est possible légalement.

### 1.1 Migration DB — Champs DSN obligatoires

**Fichier** : `db/migrate/YYYYMMDD_add_payroll_fields_to_employees.rb`

```ruby
class AddPayrollFieldsToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :nir,                  :string, limit: 15   # N° sécurité sociale (13 chiffres + 2 clé)
    add_column :employees, :nir_key,               :string, limit: 2    # Clé NIR séparée
    add_column :employees, :birth_date,            :date
    add_column :employees, :birth_city,            :string
    add_column :employees, :birth_department,      :string, limit: 3    # 2A, 2B, 75, etc.
    add_column :employees, :birth_country,         :string, default: 'FR'
    add_column :employees, :nationality,           :string, default: 'FR'
    add_column :employees, :iban,                  :string              # Chiffré (voir sécurité)
    add_column :employees, :bic,                   :string
    add_column :employees, :convention_collective, :string              # IDCC ex: "1486" (Bureaux d'études)
    add_column :employees, :qualification,         :string              # Ex: "Cadre niveau 2"
    add_column :employees, :coefficient,           :string              # Ex: "360"
    add_column :employees, :part_time_rate,        :decimal, precision: 5, scale: 4, default: 1.0  # 1.0 = temps plein, 0.8 = 80%
    add_column :employees, :trial_period_end,      :date
    add_column :employees, :contract_end_date,     :date                # Pour CDD
    add_column :employees, :termination_date,      :date
    add_column :employees, :termination_reason,    :string              # Démission, licenciement, rupture conv.

    add_index :employees, :nir, unique: true, where: "nir IS NOT NULL"
    add_index :employees, :birth_date
  end
end
```

**Champs optionnels (phase 2)** :
```ruby
add_column :employees, :mutuelle_ref,        :string   # Référence mutuelle
add_column :employees, :prevoyance_ref,      :string   # Prévoyance
add_column :employees, :taux_at,             :decimal  # Taux accident du travail (variable par secteur)
add_column :employees, :classification_code, :string   # Code classification CCN
```

### 1.2 Sécurité — NIR et IBAN chiffrés

Le NIR et l'IBAN sont des données sensibles. **Ne pas stocker en clair.**

**Option recommandée** : gem `attr_encrypted` ou chiffrement applicatif via ActiveSupport::MessageEncryptor.

```ruby
# Gemfile
gem "attr_encrypted", "~> 4.0"

# Employee model
attr_encrypted :nir,  key: Rails.application.credentials.dig(:encryption, :employee_key)
attr_encrypted :iban, key: Rails.application.credentials.dig(:encryption, :employee_key)

# credentials.yml.enc
encryption:
  employee_key: <32-byte random key — bundle exec rails secret | head -c 64>
```

> ⚠️ Le NIR est une donnée de catégorie spéciale au sens RGPD (art. 9). Journaliser tout accès via AuditLog.

### 1.3 Validations à ajouter dans Employee

```ruby
# Format NIR: 13 chiffres (ignoré si blank — saisie progressive)
validates :nir, format: { with: /\A[12][0-9]{12}\z/ }, allow_blank: true
validates :part_time_rate, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
validates :contract_end_date, presence: true, if: -> { contract_type == 'CDD' }
validates :trial_period_end, presence: true, if: -> { contract_type.in?(%w[CDI CDD]) }
```

### 1.4 UI — Formulaire Admin::EmployeesController

Ajouter un onglet "Informations paie" dans `app/views/admin/employees/edit.html.erb` :

- Section "Identité légale" : date/lieu de naissance, nationalité, NIR (champ masqué `****...`)
- Section "Coordonnées bancaires" : IBAN + BIC (champ masqué)
- Section "Contrat" : convention collective (dropdown IDCC), qualification, coefficient, taux temps partiel, date fin période d'essai
- Section "Fin de contrat" : date de résiliation + motif (conditionnel)

### 1.5 AuditLog — tracer les accès NIR/IBAN

```ruby
# Dans Admin::EmployeesController#show (et API)
after_action :log_sensitive_access, only: [:show]

def log_sensitive_access
  AuditLog.create!(
    organization: current_organization,
    actor: current_employee,
    action: 'viewed_payroll_data',
    auditable: @employee,
    metadata: { ip: request.remote_ip }
  )
end
```

---

## SPRINT 2 — Logique de calcul paie + export enrichi (semaines 3-4)

### Objectif
Créer un `PayrollCalculatorService` qui produit une fiche de paie brute (non officielle) à partir des données RH, et enrichir l'export CSV pour Silae/ADP.

### 2.1 PayrollCalculatorService

**Fichier** : `app/services/payroll/payroll_calculator_service.rb`

```ruby
# Calcule le brut mensuel à partir des données temps + planning
# Utilisé pour vérification interne, pas substitut au logiciel de paie
#
# Inputs:
#   employee:  Employee
#   period:    Date (1er du mois visé)
#
# Output:
#   {
#     base_salary:          2500.0,   # Salaire brut contractuel proratisé
#     worked_hours:         151.67,   # Heures pointées + validées
#     contractual_hours:    151.67,   # Heures contractuelles du mois
#     overtime_25:          4.0,      # Heures sup ≤ 8h/semaine (majoration 25%)
#     overtime_50:          0.0,      # Heures sup > 8h/semaine (majoration 50%)
#     overtime_bonus:       40.0,     # Montant majoration heures sup
#     leave_days_cp:        2.0,      # Jours CP pris
#     leave_days_rtt:       1.0,      # Jours RTT pris
#     leave_days_sick:      0.0,
#     leave_deduction:      0.0,      # Retenue absence injustifiée
#     gross_total:          2540.0,   # Brut total calculé
#     note:                 "Estimatif — confirmer avec logiciel de paie"
#   }
class Payroll::PayrollCalculatorService
  # ...
end
```

**Logique clé à implémenter** :

```
heures_contractuelles_mois = (weekly_hours / 5) × jours_ouvrés_du_mois
heures_réelles = SUM(time_entries.duration) WHERE validated = true AND period = mois

delta = heures_réelles - heures_contractuelles_mois

Si delta > 0:
  sup_25 = MIN(delta, 8h × semaines_du_mois)  # 4 premières heures/semaine
  sup_50 = MAX(0, delta - sup_25)               # Au-delà

taux_horaire = gross_salary / heures_contractuelles_mois
bonus_25 = sup_25 × taux_horaire × 1.25
bonus_50 = sup_50 × taux_horaire × 1.50

Congés non payés (Sans Solde) → retenue = jours × (gross_salary / jours_ouvrés)
```

> ⚠️ Ce calcul est un estimatif. Les taux de cotisations réels dépendent de la convention collective et sont calculés par Silae/ADP. On ne calcule jamais le net ici.

### 2.2 Export CSV enrichi pour Silae/ADP

**Fichier** : `app/services/exports/payroll_silae_csv_exporter.rb`

Colonnes cibles (format Silae standard) :

| Colonne | Source |
|---------|--------|
| Matricule | `employee.id` (ou champ dédié) |
| NIR | `employee.nir` (déchiffré) |
| Nom | `employee.last_name` |
| Prénom | `employee.first_name` |
| Date naissance | `employee.birth_date` |
| Lieu naissance | `employee.birth_city` |
| Dép. naissance | `employee.birth_department` |
| Nationalité | `employee.nationality` |
| IBAN | `employee.iban` |
| BIC | `employee.bic` |
| Type contrat | `employee.contract_type` |
| Convention collective | `employee.convention_collective` (IDCC) |
| Qualification | `employee.qualification` |
| Coefficient | `employee.coefficient` |
| Date entrée | `employee.start_date` |
| Taux temps partiel | `employee.part_time_rate` |
| Salaire brut | `employee.gross_salary` |
| Part variable | `employee.variable_pay` |
| Heures contractuelles/mois | calculé depuis `work_schedule` |
| Heures pointées/mois | depuis `time_entries` validés |
| Heures sup 25% | depuis `PayrollCalculatorService` |
| Heures sup 50% | depuis `PayrollCalculatorService` |
| Jours CP pris | depuis `leave_requests` approuvés |
| Jours RTT pris | idem |
| Jours maladie | idem |
| Jours sans solde | idem |
| Département | `employee.department` |
| Cadre | `employee.cadre?` |
| Manager | `employee.manager.full_name` |

### 2.3 Nouveau controller + route

```ruby
# config/routes.rb — dans namespace :admin
get 'payroll/export_silae', to: 'payroll#export_silae'

# app/controllers/admin/payroll_controller.rb
def export_silae
  authorize :payroll, :export?
  period = Date.parse(params[:period]) rescue Date.current.beginning_of_month
  result = Exports::PayrollSilaeCsvExporter.new(
    manager: current_employee,
    period: period
  ).export
  send_data result[:content], filename: result[:filename], type: 'text/csv'
end
```

### 2.4 Break tracking (temps de pause)

Actuellement `TimeEntry` n'a pas de notion de pause. Les logiciels de paie distinguent :
- Heures brutes (clock in → clock out)
- Heures nettes (déduction pauses légales)

**Migration** :
```ruby
add_column :time_entries, :break_duration_minutes, :integer, default: 0
```

**Règle légale FR** : pause obligatoire 20 min après 6h de travail continu.
→ Ajouter validation côté validation manager : si durée > 6h et break = 0 → warning (pas blocant).

---

## SPRINT 3 — API webhook sortante (semaines 5-6)

### Objectif
Permettre à Silae/ADP de puller les données via API (ou Easy-RH de pusher via webhook) à chaque clôture de paie.

### 3.1 Endpoint API REST `/api/v1/payroll`

```ruby
# config/routes.rb — dans namespace :api, namespace :v1
namespace :payroll do
  get  :employees,    to: 'payroll#employees'    # Données RH complètes
  get  :time_summary, to: 'payroll#time_summary' # Heures par employé et période
  get  :leaves,       to: 'payroll#leaves'       # Absences par employé et période
end
```

**Authentification** : token API par organisation (pas JWT employé).

```ruby
# Migration
add_column :organizations, :payroll_api_token, :string
add_index  :organizations, :payroll_api_token, unique: true

# Génération
org.update!(payroll_api_token: SecureRandom.hex(32))
```

**Exemple réponse** `GET /api/v1/payroll/employees` :

```json
{
  "period": "2026-02",
  "generated_at": "2026-02-28T10:00:00Z",
  "employees": [
    {
      "id": 42,
      "nir": "1 85 09 75 123 456 78",
      "last_name": "Dupont",
      "first_name": "Marie",
      "birth_date": "1985-09-15",
      "contract_type": "CDI",
      "convention_collective": "1486",
      "gross_salary": 3200.00,
      "part_time_rate": 1.0,
      "worked_hours": 155.5,
      "contractual_hours": 151.67,
      "overtime_25h": 3.83,
      "overtime_50h": 0,
      "leave_days": {
        "CP": 2.0,
        "RTT": 1.0,
        "Maladie": 0,
        "Parental": 0,
        "Sans solde": 0
      },
      "iban": "FR76...",
      "bic": "BNPAFRPP"
    }
  ]
}
```

### 3.2 Webhook push (optionnel — Silae le supporte)

```ruby
# app/jobs/payroll_webhook_job.rb
class PayrollWebhookJob < ApplicationJob
  queue_as :critical

  def perform(organization_id, period)
    org = Organization.find(organization_id)
    return unless org.payroll_webhook_url.present?

    payload = Payroll::PayrollApiSerializer.new(org, period).as_json
    Faraday.post(org.payroll_webhook_url, payload.to_json, {
      'Content-Type'  => 'application/json',
      'Authorization' => "Bearer #{org.payroll_webhook_secret}"
    })
  end
end
```

**Déclenchement** : manuel (bouton "Envoyer à Silae") ou automatique le dernier vendredi du mois (Sidekiq cron).

### 3.3 UI — Page "Clôture de paie"

**Route** : `/admin/payroll/close` (nouveau)

Contenu de la page :
- Sélecteur de période (mois)
- Récapitulatif : N employés · X heures sup · Y jours d'absences
- Bouton "Exporter CSV Silae"
- Bouton "Envoyer via webhook" (si configuré)
- Statut du dernier envoi (timestamp + succès/erreur)
- Historique des exports (log)

---

## RÉCAPITULATIF PAR SPRINT

| Sprint | Contenu | Fichiers créés/modifiés | Priorité |
|--------|---------|------------------------|----------|
| **1** | Champs DSN, NIR chiffré, IBAN, validations, UI formulaire | Migration, Employee model, Admin form, AuditLog | 🔴 CRITIQUE |
| **2** | PayrollCalculatorService, export Silae CSV enrichi, break tracking | 2 nouveaux services, 1 migration, 1 exporter | 🟠 HAUTE |
| **3** | API REST `/api/v1/payroll`, webhook push, UI clôture | 3 controllers API, 1 job, 1 vue admin | 🟡 MOYENNE |

---

## CHECKLIST FINALE (100/100)

### Données (Sprint 1)
- [ ] NIR stocké chiffré
- [ ] IBAN/BIC stocké chiffré
- [ ] Date/lieu de naissance présents
- [ ] Nationalité présente
- [ ] Convention collective (IDCC) présente
- [ ] Qualification/coefficient présents
- [ ] Taux temps partiel présent
- [ ] Date fin période d'essai présente
- [ ] Accès NIR/IBAN tracé dans AuditLog

### Calcul (Sprint 2)
- [ ] `PayrollCalculatorService` fonctionnel
- [ ] Heures sup 25% calculées correctement
- [ ] Heures sup 50% calculées correctement
- [ ] Retenue absence sans solde calculée
- [ ] Break tracking sur `TimeEntry`
- [ ] Export CSV format Silae (28 colonnes)

### Intégration (Sprint 3)
- [ ] API REST `/api/v1/payroll` sécurisée (token org)
- [ ] Réponse JSON incluant heures + absences + données DSN
- [ ] Webhook push configurable par organisation
- [ ] UI page "Clôture de paie"
- [ ] Historique des exports

### Sécurité & Conformité
- [ ] NIR/IBAN jamais loggés en clair (Lograge, Sentry)
- [ ] Accès données paie limité HR/Admin (Pundit)
- [ ] Mentions RGPD dans politique de confidentialité
- [ ] Registre des traitements mis à jour (NIR = donnée sensible)
- [ ] DPO notifié si export NIR activé

---

## NOTES IMPORTANTES

### Ce qu'on ne fait PAS (hors périmètre Easy-RH)
- Calcul des cotisations sociales (patronales + salariales) → Silae/ADP
- Génération du bulletin de salaire officiel → Silae/ADP
- Déclaration DSN → Silae/ADP
- Calcul du net à payer → Silae/ADP

### Positionnement
Easy-RH est le **SIRH source de vérité** pour les données RH.
Silae/ADP est le **logiciel de paie** qui consomme ces données.
L'intégration = Easy-RH expose des données propres → Silae calcule la paie.

### Convention collective
La liste des IDCC est publique (site du ministère du Travail).
Prévoir un dropdown avec les 50 conventions les plus courantes + saisie libre.
Exemples : 1486 (Bureaux d'études), 3218 (Métallurgie), 1090 (Commerces alimentaires).

---

*Dernière mise à jour : 2026-02-28 par @architect*
