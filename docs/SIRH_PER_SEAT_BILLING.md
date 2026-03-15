# SIRH — Per-Seat Billing

**Statut** : 📋 À implémenter (post-MVP)
**Créé** : 2026-03-16

---

## Contexte stratégique

Le SIRH est vendu en B2B aux équipes RH de PME (20-200 employés). Le manager individuel est le cheval de Troie via Manager OS — il convainc son RH de souscrire au SIRH pour toute l'organisation.

Le comptage se fait sur les **employés actifs** de l'organisation (pas les managers seuls).

---

## Modèle tarifaire

| Plan | Prix fixe | Inclus | Au-delà |
|------|-----------|--------|---------|
| SIRH Essentiel | 79 €/mois | 30 employés | +3 €/employé/mois |
| SIRH Pro | 149 €/mois | 50 employés | +2,50 €/employé/mois |

**Exemples :**
- Essentiel, 40 employés : `79 + (10 × 3) = 109 €/mois` → 2,73 €/employé
- Pro, 80 employés : `149 + (30 × 2,50) = 224 €/mois` → 2,80 €/employé

Le Pro devient moins cher au siège au-delà de ~70 employés → incite à upgrader.

---

## Différence avec Manager OS

| | Manager OS | SIRH |
|--|------------|------|
| Décisionnaire | Manager individuel (B2C) | RH / DG (B2B) |
| Unité comptée | Membres invités par le manager | Employés actifs de l'org |
| Déclencheur | Nouvelle invitation | Création/activation d'un employé |
| Budget | Poche du manager | Budget entreprise |

---

## Implémentation technique requise

### 1. Nouveaux prix Stripe

Créer deux prix per-unit (un par plan) :

```
SIRH Essentiel :
  type: recurring, per_unit
  unit_amount: 300  (3 €)
  flat_fee: 7900    (79 € de base)

SIRH Pro :
  type: recurring, per_unit
  unit_amount: 250  (2,50 €)
  flat_fee: 14900   (149 € de base)
```

→ Utiliser **Stripe Pricing Tiers** avec `tiers_mode: graduated` ou modèle flat fee + per-seat séparé.

### 2. Compteur d'employés

```ruby
# Organization model
def sirh_seat_count
  employees.active.count
end

def sirh_extra_seats(included:)
  [sirh_seat_count - included, 0].max
end

def sirh_monthly_price
  case plan
  when 'sirh_essentiel'
    79 + (sirh_extra_seats(included: 30) * 3)
  when 'sirh_pro'
    149 + (sirh_extra_seats(included: 50) * 2.5)
  end
end
```

### 3. Mise à jour Stripe à la création d'employé

Contrairement à Manager OS (confirmation modale), le SIRH ajuste silencieusement la quantité à chaque création/désactivation d'employé :

```ruby
# SirhSeatService (nouveau service)
class SirhSeatService
  def sync_seats!(organization)
    return unless organization.sirh_plan?

    subscription = Stripe::Subscription.retrieve(organization.stripe_subscription_id)
    Stripe::Subscription.update(subscription.id, {
      items: [{ id: seat_item_id(subscription), quantity: organization.sirh_seat_count }],
      proration_behavior: 'always_invoice'
    })
  end
end
```

Appeler `SirhSeatService.new.sync_seats!(org)` dans :
- `EmployeeCreationService` (après activation)
- `EmployeeDeactivationService` (après désactivation)

### 4. Email de confirmation

À chaque ajustement, envoyer un email au RH/admin :
> *"Votre organisation compte maintenant X employés actifs. Votre prochain prélèvement sera de Y €/mois."*

---

## Fichiers à créer/modifier

| Fichier | Action |
|---------|--------|
| `app/domains/billing/services/sirh_seat_service.rb` | Créer |
| `app/domains/employees/services/employee_creation_service.rb` | Modifier — appel sync_seats! |
| `app/domains/employees/services/employee_deactivation_service.rb` | Modifier — appel sync_seats! |
| `app/domains/billing/models/organization.rb` | Modifier — seat helpers |
| `app/mailers/billing_mailer.rb` | Modifier — email ajustement siège |
| `spec/domains/billing/services/sirh_seat_service_spec.rb` | Créer |
| Stripe Dashboard | Créer nouveaux prix per-unit Essentiel + Pro |
| `.env` / Render | Ajouter `STRIPE_SIRH_ESSENTIEL_SEAT_PRICE_ID`, `STRIPE_SIRH_PRO_SEAT_PRICE_ID` |

---

## Migration clients existants

Lors du lancement :
- Orgs SIRH avec ≤ seuil inclus : rien à faire
- Orgs SIRH avec > seuil inclus : migration manuelle Stripe ou grace period 30 jours

---

*À planifier en Phase 7 ou dès les premiers clients SIRH réels.*
