# Configuration des Politiques de Congés

## Architecture de Résolution en Cascade

Le système Izi-RH implémente une architecture flexible de gestion des congés basée sur **4 niveaux hiérarchiques** :

```
Code du travail (base légale - constantes par défaut)
    ↓
Convention Collective (IDCC - par secteur) [TODO]
    ↓
Accord d'entreprise (Organization.settings)
    ↓
Contrat individuel (Employee.contract_overrides)
```

### Principe de Fonctionnement

La résolution des règles suit un ordre de **priorité décroissante** :

1. **Contrat individuel** : Clauses spécifiques négociées pour l'employé
2. **Accord d'entreprise** : Règles propres à l'organisation
3. **Convention collective** : Règles sectorielles (Syntec, Bâtiment, Métallurgie, etc.) [TODO]
4. **Code du travail** : Minimum légal français

Si une règle n'est pas définie à un niveau, le système remonte au niveau supérieur.

## Paramètres Configurables

### Constantes de Base (Code du travail)

```ruby
# app/domains/leave_management/services/leave_policy_engine.rb
LEGAL_DEFAULTS = {
  cp_acquisition_rate: 2.5,           # jours de CP par mois travaillé
  cp_acquisition_period_months: 12,   # période d'acquisition en mois
  cp_max_annual: 30,                  # maximum de CP par an
  cp_expiry_month: 5,                 # mois d'expiration (mai)
  cp_expiry_day: 31,                  # jour d'expiration (31 mai)
  minimum_consecutive_leave_days: 10, # jours consécutifs minimums en été
  legal_work_week_hours: 35,          # durée légale hebdomadaire
  rtt_calculation_threshold: 35,      # seuil de calcul RTT
  auto_approve_threshold_days: 15,    # solde CP min pour auto-validation
  auto_approve_max_request_days: 2    # durée max pour auto-validation
}
```

## Niveau 1 : Contrat Individuel (Priorité Max)

### Configuration par Employé

Permet de personnaliser les règles pour un employé spécifique (cadres, temps partiel, contrats spéciaux) :

```ruby
# Rails console
employee = Employee.find(123)
employee.contract_overrides = {
  "cp_acquisition_rate" => 3.0,        # 3 jours/mois au lieu de 2.5
  "minimum_consecutive_leave_days" => 5 # 5 jours au lieu de 10
}
employee.save!
```

### Cas d'Usage Typiques

**Cadre dirigeant avec 35 jours de CP/an :**
```ruby
employee.contract_overrides = {
  "cp_acquisition_rate" => 2.92,  # 35 jours / 12 mois
  "cp_max_annual" => 35
}
```

**Temps partiel (80%) :**
```ruby
# Le prorata est calculé automatiquement via work_schedule.weekly_hours
# Pas besoin de contract_overrides sauf clause spéciale
employee.work_schedule.update(weekly_hours: 28)  # 80% de 35h
```

**Convention de forfait jours cadre :**
```ruby
employee.contract_overrides = {
  "rtt_calculation_threshold" => 0,  # Pas de RTT pour les forfaits jours
  "legal_work_week_hours" => 218     # 218 jours/an
}
```

## Niveau 2 : Accord d'Entreprise

### Configuration par Organisation

Permet de définir des règles spécifiques à l'entreprise (via `Organization.settings`) :

```ruby
# Rails console
org = Organization.find(1)
org.settings = {
  "cp_acquisition_rate" => 2.5,
  "cp_expiry_month" => 6,              # Expiration au 30 juin au lieu de 31 mai
  "cp_expiry_day" => 30,
  "minimum_consecutive_leave_days" => 8, # 8 jours au lieu de 10
  "auto_approve_threshold_days" => 20,   # Auto-validation si solde > 20j
  "auto_approve_max_request_days" => 3,  # Auto-validation jusqu'à 3 jours
  "rtt_enabled" => true,
  "work_week_hours" => 35
}
org.save!
```

### Exemples par Secteur

**Entreprise du secteur bancaire (généreuse) :**
```ruby
org.settings = {
  "cp_acquisition_rate" => 2.75,  # 33 jours/an
  "cp_max_annual" => 33,
  "auto_approve_threshold_days" => 25
}
```

**Startup avec accord RTT avantageux :**
```ruby
org.settings = {
  "rtt_calculation_threshold" => 32,  # RTT dès 32h/semaine
  "work_week_hours" => 39,
  "rtt_enabled" => true
}
```

## Niveau 3 : Convention Collective [TODO]

### Implémentation Future

Pour supporter les différentes conventions collectives (IDCC), il faudra :

1. **Créer un modèle CollectiveAgreement :**
```ruby
# db/migrate/xxx_create_collective_agreements.rb
create_table :collective_agreements do |t|
  t.string :name              # "Convention Syntec"
  t.string :idcc              # "1486"
  t.jsonb :settings, default: {}, null: false
  t.timestamps
end

add_column :organizations, :collective_agreement_id, :bigint
add_foreign_key :organizations, :collective_agreements
```

2. **Activer la résolution dans LeavePolicyEngine :**
```ruby
# Actuellement commenté (ligne 50-54)
if organization.collective_agreement&.settings&.key?(key.to_s)
  return organization.collective_agreement.settings[key.to_s]
end
```

3. **Pré-remplir les conventions courantes :**
```ruby
# db/seeds.rb
CollectiveAgreement.create!(
  name: "Convention Syntec",
  idcc: "1486",
  settings: {
    "cp_acquisition_rate" => 2.5,
    "minimum_consecutive_leave_days" => 12,  # Syntec exige 12 jours
    "cp_max_annual" => 30
  }
)

CollectiveAgreement.create!(
  name: "Convention Métallurgie",
  idcc: "3109",
  settings: {
    "cp_acquisition_rate" => 2.5,
    "cp_max_annual" => 30,
    "minimum_consecutive_leave_days" => 10
  }
)
```

## Exemples de Scénarios Complexes

### Scénario 1 : Cadre dans une startup avec convention Syntec

```ruby
# Convention Syntec (IDCC 1486)
collective_agreement.settings = {
  "minimum_consecutive_leave_days" => 12
}

# Accord d'entreprise startup
organization.settings = {
  "cp_acquisition_rate" => 2.75,  # 33 jours
  "auto_approve_max_request_days" => 5
}

# Contrat cadre dirigeant
employee.contract_overrides = {
  "cp_max_annual" => 35
}

# Résolution pour "cp_max_annual" :
# 1. employee.contract_overrides["cp_max_annual"] = 35 ✓ UTILISÉ
# 2. organization.settings (pas défini, on continue)
# 3. collective_agreement.settings (pas défini, on continue)
# 4. LEGAL_DEFAULTS[:cp_max_annual] = 30

# Résolution pour "minimum_consecutive_leave_days" :
# 1. employee.contract_overrides (pas défini, on continue)
# 2. organization.settings (pas défini, on continue)
# 3. collective_agreement.settings["minimum_consecutive_leave_days"] = 12 ✓ UTILISÉ
```

### Scénario 2 : Temps partiel avec contrat spécifique

```ruby
# Employee avec 28h/semaine (80%)
employee.work_schedule.weekly_hours = 28

# Clause contractuelle : maintien à 100% des CP malgré temps partiel
employee.contract_overrides = {
  # Pas de prorata automatique, forcer le taux plein
  # Le part_time_ratio sera ignoré pour ce paramètre spécifique
}

# Note : Pour implémenter ce cas, il faudrait ajouter un flag "ignore_part_time_ratio"
```

## Migration des Organisations Existantes

Pour migrer une organisation existant vers le nouveau système :

```ruby
# Script de migration (bin/rails runner)
Organization.find_each do |org|
  # Récupérer les settings actuels (déjà existants)
  current_settings = org.settings || {}

  # S'assurer que toutes les clés importantes sont présentes
  default_settings = {
    "cp_acquisition_rate" => 2.5,
    "cp_max_annual" => 30,
    "cp_expiry_month" => 5,
    "cp_expiry_day" => 31,
    "minimum_consecutive_leave_days" => 10,
    "legal_work_week_hours" => 35,
    "rtt_calculation_threshold" => 35,
    "rtt_enabled" => true,
    "auto_approve_threshold_days" => 15,
    "auto_approve_max_request_days" => 2
  }

  # Fusionner (les settings existants ont priorité)
  org.settings = default_settings.merge(current_settings)
  org.save!

  puts "✓ Organization #{org.name} migrated"
end
```

## Tests et Validation

### Tester la Résolution en Cascade

```ruby
# spec/domains/leave_management/services/leave_policy_engine_spec.rb

RSpec.describe LeaveManagement::Services::LeavePolicyEngine do
  describe "#get_setting" do
    let(:organization) { create(:organization, settings: { "cp_acquisition_rate" => 2.7 }) }
    let(:employee) { create(:employee, organization: organization) }
    let(:engine) { described_class.new(employee) }

    context "when setting is in employee contract_overrides" do
      before do
        employee.update(contract_overrides: { "cp_acquisition_rate" => 3.0 })
      end

      it "returns the employee override value" do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(3.0)
      end
    end

    context "when setting is only in organization" do
      it "returns the organization value" do
        expect(engine.get_setting(:cp_acquisition_rate)).to eq(2.7)
      end
    end

    context "when setting is nowhere" do
      it "returns the legal default" do
        expect(engine.get_setting(:cp_max_annual)).to eq(30)
      end
    end
  end
end
```

## Prochaines Étapes

- [ ] Implémenter le modèle `CollectiveAgreement`
- [ ] Créer une interface admin pour gérer les accords d'entreprise
- [ ] Ajouter une page de configuration des overrides individuels
- [ ] Créer un tableau de bord affichant les règles appliquées pour chaque employé
- [ ] Ajouter un système de validation des settings (empêcher cp_acquisition_rate négatif, etc.)
- [ ] Logger les changements de settings pour audit

## Références Légales

- **Code du travail français** : Articles L3141-1 à L3141-33 (Congés payés)
- **Convention Syntec (IDCC 1486)** : Article 4.5 (Congés payés)
- **Convention Métallurgie (IDCC 3109)** : Article 4.2 (Congés)

---

**Documentation générée le** : 2026-01-04
**Version** : 1.0.0
**Maintenu par** : Équipe Izi-RH
