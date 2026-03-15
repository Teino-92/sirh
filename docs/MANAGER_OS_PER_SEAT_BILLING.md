# Manager OS — Per-Seat Billing

**Statut** : 📋 À implémenter (post-MVP)
**Créé** : 2026-03-16

---

## Modèle tarifaire

- **19 €/mois** — forfait fixe, inclut **6 membres d'équipe** (le manager + 5 collaborateurs)
- **+2 €/mois** par membre supplémentaire à partir du 7ème

**Exemple** : manager avec 10 collaborateurs = `19 + (4 × 2) = 27 €/mois`

---

## Flow UX à implémenter

1. Manager tente d'inviter un Nème membre (N > 6)
2. App affiche une modale de confirmation :
   > *"Votre équipe compte déjà 6 membres inclus dans votre forfait. Ajouter ce membre coûtera **+2 €/mois**. Votre abonnement passera à **X €/mois** dès aujourd'hui (prorata), puis à **X €/mois** le prochain cycle. Confirmer ?"*
3. Manager accepte → Stripe ajuste la quantité → prélève le prorata immédiatement
4. Mois suivant : facturation au nouveau tarif

---

## Implémentation technique requise

### 1. Nouveau Price Stripe (per-unit)

Le plan Manager OS actuel est un **flat rate**. Il faut créer un nouveau prix Stripe :

```
type: recurring
billing_scheme: per_unit
unit_amount: 200  (2 €)
currency: eur
recurring.interval: month
recurring.usage_type: licensed
```

Le forfait de base (19 €) devient un **prix fixe** + un **prix par siège** avec `quantity: 0` au départ.

**Alternative plus simple** : utiliser un seul prix `per_unit` à 2 €/siège avec un minimum de `quantity: 9` (les 6 inclus sont couverts par les 19 € via un "flat fee" séparé).

→ **Recommandation** : Stripe [Pricing with tiers](https://stripe.com/docs/billing/subscriptions/tiers) ou modèle 2 prix (flat fee + per-seat).

### 2. Compteur de membres dans l'app

```ruby
# Organization model
def manager_os_seat_count
  employees.active.count  # ou employees.where(role: [:employee, :manager]).count
end

def manager_os_extra_seats
  [manager_os_seat_count - 6, 0].max
end

def manager_os_monthly_price
  19 + (manager_os_extra_seats * 2)
end
```

### 3. Gate sur l'invitation

Dans le service/controller d'invitation d'employé (Manager OS plan uniquement) :

```ruby
# Avant de créer l'employé
if organization.plan == 'manager_os' && organization.manager_os_seat_count >= 6
  # Afficher modale de confirmation avec le nouveau prix calculé
  # Si confirmé → appel Stripe puis création employé
end
```

### 4. Mise à jour Stripe à la confirmation

```ruby
# ManagerOsSeatService (nouveau service à créer)
class ManagerOsSeatService
  def add_seat!(organization)
    subscription = Stripe::Subscription.retrieve(organization.stripe_subscription_id)
    new_quantity = organization.manager_os_seat_count + 1 - 6  # extras après les 6 inclus

    Stripe::Subscription.update(subscription.id, {
      items: [{
        id: subscription.items.data[1].id,  # l'item per-seat
        quantity: new_quantity
      }],
      proration_behavior: 'always_invoice'  # prélève le prorata immédiatement
    })
  end
end
```

### 5. Webhook à gérer

`invoice.payment_succeeded` — déjà géré, mais vérifier que la mise à jour de quantité déclenche bien un email de confirmation au manager.

---

## Migration des clients existants

Lors du lancement de ce feature :
- Les orgs Manager OS existantes avec ≤ 6 membres : rien à faire
- Les orgs Manager OS existantes avec > 6 membres : migration manuelle Stripe ou grace period

---

## Fichiers à créer/modifier

| Fichier | Action |
|---------|--------|
| `app/domains/billing/services/manager_os_seat_service.rb` | Créer |
| `app/controllers/employees_controller.rb` (ou invitations) | Modifier — ajouter gate |
| `app/views/employees/new.html.erb` (ou modal) | Modifier — modale confirmation |
| `app/domains/billing/models/organization.rb` | Modifier — seat helpers |
| `spec/domains/billing/services/manager_os_seat_service_spec.rb` | Créer |
| Stripe Dashboard | Créer nouveau price per-unit |
| `.env` / Render | Ajouter `STRIPE_MANAGER_OS_SEAT_PRICE_ID` |

---

## Décision architecture

- **Pas de Stripe Metered** (usage-based) — trop complexe, async, reporting en fin de période
- **Stripe Licensed per-seat** — synchrone, prélèvement immédiat, cohérent avec le modèle SaaS classique
- **Gate applicatif** — l'app contrôle le quota, Stripe ne fait que facturer

---

*À planifier en Phase 7 ou dès qu'un client Manager OS dépasse 6 membres.*
