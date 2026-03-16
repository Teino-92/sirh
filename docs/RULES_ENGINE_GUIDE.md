# Rules Engine — Guide de configuration client

Le moteur de règles permet de configurer des workflows métier sur mesure **sans toucher au code**.
Chaque règle est un enregistrement `BusinessRule` en base de données, activable/désactivable par organisation.

---

## Structure d'une règle

```ruby
BusinessRule.create!(
  organization: org,
  name:         "Nom lisible de la règle",
  trigger:      "domain.event",       # événement déclencheur
  conditions:   [...],                # tableau de conditions (AND) — vide = toujours déclenché
  actions:      [...],                # tableau d'actions exécutées dans l'ordre
  priority:     0,                    # plus petit = évalué en premier
  active:       true
)
```

La feature flag doit être activée sur l'organisation :

```ruby
org.update!(settings: org.settings.merge('rules_engine_enabled' => true))
```

---

## Triggers disponibles

Un trigger est une string au format `"domain.event"`. N'importe quelle valeur est acceptée.

### Congés (intégrés)

| Trigger | Moment |
|---------|--------|
| `leave_request.submitted` | Demande de congé soumise |
| `leave_request.approved`  | Demande approuvée |
| `leave_request.rejected`  | Demande rejetée |
| `leave_request.cancelled` | Demande annulée |

### Ajouter un nouveau trigger

Il suffit d'appeler `RulesEngine.new(org).trigger("mon.event", resource: objet, context: hash)` depuis le code métier concerné. Aucune modification du modèle `BusinessRule` n'est nécessaire.

---

## Conditions

Les conditions sont évaluées en **AND** — toutes doivent être vraies pour que la règle se déclenche. Un tableau vide = la règle se déclenche toujours.

### Format

```json
{ "field": "nom_du_champ", "operator": "opérateur", "value": "valeur" }
```

### Opérateurs disponibles

| Opérateur | Description | Exemple |
|-----------|-------------|---------|
| `eq`      | Égal | `{ "field": "leave_type", "operator": "eq", "value": "CP" }` |
| `neq`     | Différent | `{ "field": "leave_type", "operator": "neq", "value": "RTT" }` |
| `gt`      | Supérieur strict | `{ "field": "days_count", "operator": "gt", "value": 10 }` |
| `gte`     | Supérieur ou égal | `{ "field": "days_count", "operator": "gte", "value": 5 }` |
| `lt`      | Inférieur strict | `{ "field": "days_count", "operator": "lt", "value": 3 }` |
| `lte`     | Inférieur ou égal | `{ "field": "days_count", "operator": "lte", "value": 2 }` |
| `in`      | Dans une liste | `{ "field": "leave_type", "operator": "in", "value": ["CP", "RTT"] }` |
| `between` | Entre deux valeurs (inclusif) | `{ "field": "days_count", "operator": "between", "value": [5, 10] }` |
| `present` | Le champ est présent (non vide) | `{ "field": "comment", "operator": "present" }` |
| `blank`   | Le champ est vide/absent | `{ "field": "comment", "operator": "blank" }` |

### Champs disponibles pour `leave_request.submitted`

| Champ | Type | Description |
|-------|------|-------------|
| `leave_type` | string | Type de congé (`CP`, `RTT`, `MALADIE`, etc.) |
| `days_count` | float | Nombre de jours demandés |
| `start_date` | string (YYYY-MM-DD) | Date de début |
| `end_date` | string (YYYY-MM-DD) | Date de fin |
| `employee_role` | string | Rôle de l'employé |

> Pour un nouveau trigger, le caller définit librement les champs du contexte.

---

## Actions

Les actions sont exécutées **dans l'ordre** du tableau.

### `require_approval` — Demande d'approbation

Crée une étape d'approbation dans la chaîne N-niveaux.

```json
{ "type": "require_approval", "role": "manager", "order": 1 }
```

| Paramètre | Description |
|-----------|-------------|
| `role` | Rôle requis pour approuver (`manager`, `hr`, `admin`) |
| `order` | Position dans la chaîne (1 = première étape) |

### `auto_approve` — Approbation automatique

Approuve automatiquement la ressource sans intervention humaine.

```json
{ "type": "auto_approve" }
```

### `block` — Blocage avec message

Bloque la demande et renvoie un message d'erreur à l'utilisateur.

```json
{ "type": "block", "reason": "Période de gel RH — aucun congé CP accepté en décembre" }
```

### `notify` — Notification

Envoie une notification in-app + email aux destinataires ciblés.

```json
{ "type": "notify", "role": "hr", "subject": "Congé long soumis", "message": "Une demande de congé > 10 jours a été soumise." }
```

Ou vers un employé précis :

```json
{ "type": "notify", "employee_id": 42, "subject": "FYI", "message": "Demande soumise par votre équipe." }
```

### `escalate_after` — Escalade après délai

Crée une étape d'approbation qui s'escalade automatiquement si non traitée dans le délai imparti.

```json
{ "type": "escalate_after", "role": "manager", "order": 1, "hours": 24, "escalate_to_role": "hr" }
```

| Paramètre | Description |
|-----------|-------------|
| `role` | Rôle initial requis |
| `order` | Position dans la chaîne |
| `hours` | Délai avant escalade (en heures) |
| `escalate_to_role` | Rôle vers lequel escalader |

> ⚠️ Nécessite Sidekiq (pas `:async`). Sur Render free tier, les jobs ne survivent pas aux restarts.

---

## Exemples de règles complètes

### Approbation manager pour congés > 5 jours

```ruby
BusinessRule.create!(
  organization: org,
  name:         "Approbation manager — congés longs",
  trigger:      "leave_request.submitted",
  conditions:   [{ "field" => "days_count", "operator" => "gte", "value" => 5 }],
  actions:      [{ "type" => "require_approval", "role" => "manager", "order" => 1 }],
  priority:     0,
  active:       true
)
```

### Double approbation manager → RH pour congés > 10 jours

```ruby
BusinessRule.create!(
  organization: org,
  name:         "Double approbation — congés très longs",
  trigger:      "leave_request.submitted",
  conditions:   [{ "field" => "days_count", "operator" => "gte", "value" => 10 }],
  actions:      [
    { "type" => "require_approval", "role" => "manager", "order" => 1 },
    { "type" => "require_approval", "role" => "hr",      "order" => 2 }
  ],
  priority:     0,
  active:       true
)
```

### Gel des congés CP en décembre

```ruby
BusinessRule.create!(
  organization: org,
  name:         "Gel CP décembre",
  trigger:      "leave_request.submitted",
  conditions:   [{ "field" => "leave_type", "operator" => "eq", "value" => "CP" }],
  actions:      [{ "type" => "block", "reason" => "Les congés CP sont gelés en décembre." }],
  priority:     0,
  active:       true
)
```

### Auto-approbation pour les RTT <= 1 jour

```ruby
BusinessRule.create!(
  organization: org,
  name:         "Auto-approbation RTT courte",
  trigger:      "leave_request.submitted",
  conditions:   [
    { "field" => "leave_type", "operator" => "eq",  "value" => "RTT" },
    { "field" => "days_count", "operator" => "lte", "value" => 1 }
  ],
  actions:      [{ "type" => "auto_approve" }],
  priority:     10,
  active:       true
)
```

### Notification RH + escalade si manager ne répond pas sous 48h

```ruby
BusinessRule.create!(
  organization: org,
  name:         "Escalade manager 48h",
  trigger:      "leave_request.submitted",
  conditions:   [{ "field" => "days_count", "operator" => "gte", "value" => 5 }],
  actions:      [
    { "type" => "escalate_after", "role" => "manager", "order" => 1,
      "hours" => 48, "escalate_to_role" => "hr" },
    { "type" => "notify", "role" => "hr",
      "subject" => "Demande en attente d'approbation",
      "message" => "Une demande de congé long est en attente d'approbation manager." }
  ],
  priority:     0,
  active:       true
)
```

### Congés entre 5 et 10 jours : notifier le DG pour information

```ruby
BusinessRule.create!(
  organization: org,
  name:         "FYI DG — congés moyens",
  trigger:      "leave_request.submitted",
  conditions:   [{ "field" => "days_count", "operator" => "between", "value" => [5, 10] }],
  actions:      [
    { "type" => "require_approval", "role" => "manager", "order" => 1 },
    { "type" => "notify", "role" => "admin",
      "subject" => "FYI — Congé soumis",
      "message" => "Une demande de congé entre 5 et 10 jours a été soumise." }
  ],
  priority:     0,
  active:       true
)
```

---

## Délégation temporaire

Permet à un manager de déléguer ses droits d'approbation à un collègue pendant une période définie.

```ruby
EmployeeDelegation.create!(
  organization: org,
  delegator:    manager,          # celui qui délègue (doit avoir le rôle)
  delegatee:    autre_employe,    # celui qui reçoit la délégation
  role:         'manager',        # rôle délégué
  starts_at:    Date.today.beginning_of_day,
  ends_at:      Date.today.end_of_day + 7.days,
  reason:       "Congé annuel du manager"
)
```

- Le delegator **conserve** ses propres droits pendant la délégation.
- Une délégation expirée est automatiquement ignorée (`ends_at < Time.current`).
- Une délégation future n'est pas encore active (`starts_at > Time.current`).

---

## Ajouter un nouveau domaine

Pour intégrer le moteur de règles dans un nouveau domaine (ex: notes de frais) :

1. Appeler `RulesEngine.new(org).trigger(...)` au bon endroit dans le service métier :

```ruby
# Dans ExpenseService ou ExpenseValidator
context = {
  'amount'        => expense.amount,
  'currency'      => expense.currency,
  'employee_role' => expense.employee.role,
  'category'      => expense.category
}
RulesEngine.new(organization).trigger('expense.submitted', resource: expense, context: context)
```

2. Créer les règles client avec le trigger `"expense.submitted"` et les champs de contexte définis ci-dessus.

C'est tout. Aucune modification du moteur n'est nécessaire.
