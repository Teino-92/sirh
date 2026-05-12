# Onboarding Task Validation — Design Spec

**Date:** 2026-05-12
**Statut:** Approuvé

---

## Résumé

Les tâches d'onboarding assignées à l'employé (`assigned_to_role: 'employee'`) suivent désormais un workflow en deux étapes : l'employé marque comme fait (`done`), le manager valide (`completed`). Les tâches assignées à `manager` ou `hr` conservent le comportement actuel (auto-complétées par le manager d'un seul clic).

Le score d'intégration et la progression ne changent pas de calcul — ils comptent toujours `completed`, qui représente désormais "validé par le manager" pour les tâches employé.

---

## Modèle de données

### Modifications `OnboardingTask`

**Enum status :** ajout de `done` entre `pending` et `completed`

```ruby
enum status: {
  pending:   'pending',
  done:      'done',      # nouveau — employé a marqué fait, attente validation
  completed: 'completed', # inchangé — manager a validé (ou manager/hr ont complété directement)
  overdue:   'overdue'
}
```

**Colonnes à ajouter :**

| Colonne | Type | Contraintes |
|---|---|---|
| `validated_at` | datetime | nullable |
| `validated_by_id` | bigint | FK → employees, nullable |

**Méthodes :**

```ruby
# Appelée par l'employé — uniquement sur tâches assigned_to_role: 'employee'
def mark_done!(employee)
  raise InvalidTransitionError, "seules les tâches employé peuvent être marquées faites" unless assigned_to_role == 'employee'
  raise InvalidTransitionError, "déjà complétée" if completed?
  update!(status: :done, completed_at: Time.current, completed_by: employee)
end

# Appelée par le manager — valide une tâche done
def validate!(manager)
  raise InvalidTransitionError, "la tâche doit être done avant validation" unless done?
  update!(status: :completed, validated_at: Time.current, validated_by: manager)
end

# complete! existant — conservé pour tâches manager/hr (auto-complétion directe)
# Pas de changement sur cette méthode
```

**Erreur typée :** `OnboardingTask::InvalidTransitionError < StandardError`

**Scope supplémentaire :** `scope :awaiting_validation, -> { where(status: 'done') }`

---

## Architecture

### Controllers

**`Manager::EmployeeOnboardingTasksController`** — ajout action `validate`

- `update` (existant) : inchangé — complète directement les tâches manager/hr
- `validate` (PATCH member, nouveau) : valide une tâche `done`

**`EmployeeOnboardingTasksController`** (nouveau, côté employee)

- `mark_done` (PATCH member) : marque une tâche `pending` comme `done`

### Routes

```ruby
# Manager — ajout de validate sur la ressource shallow existante
resources :employee_onboarding_tasks, only: [:update], shallow: true do
  member do
    patch :validate
  end
end

# Employee — nouveau (hors namespace manager)
resources :employee_onboarding_tasks, only: [] do
  member do
    patch :mark_done
  end
end
```

### Vues

**`manager/employee_onboardings/show`** — modifications :

- Tâches `done` : badge "À valider" (orange/warning) + bouton "Valider" (turbo stream)
- Tâches `pending` (assigned_to_role employee) : badge "En attente de l'employé" (neutre)
- Tâches `completed` : inchangé (vert, barré)
- Turbo stream `validate` : replace la ligne de tâche + refresh barre de progression

**`employee_onboardings/show`** — modifications :

- Tâches `pending` assigned_to_role `employee` : bouton "Marquer fait" (turbo stream)
- Tâches `done` : badge "En attente de validation" (orange), bouton désactivé
- Tâches `completed` : inchangé (vert, barré)
- Turbo stream `mark_done` : replace la ligne de tâche

### Turbo IDs

- Ligne tâche manager : `onboarding_task_<task_id>` (déjà existant ou à ajouter)
- Ligne tâche employee : `onboarding_task_emp_<task_id>`
- Progression manager : `onboarding_progress_<onboarding_id>` (déjà dans le show)
- Progression employee : `onboarding_emp_progress_<onboarding_id>`

---

## Sécurité

### `OnboardingTaskPolicy`

| Action | Manager | Employee | HR/Admin |
|---|---|---|---|
| `update?` | Oui (manager de l'onboarding) | Non | Oui |
| `validate?` | Oui (manager de l'onboarding) + tâche `done` | Non | Non |
| `mark_done?` | Non | Oui si `assigned_to_role == 'employee'` et `pending?` | Non |

### Invariants

- `mark_done` → 422 si tâche pas `pending` ou `assigned_to_role != 'employee'`
- `validate` → 422 si tâche pas `done`
- `validated_by` forcé = `current_employee` (pas manipulable via params)
- `completed_by` lors de `mark_done` = `current_employee`
- Multi-tenancy : `acts_as_tenant :organization` déjà présent

---

## Impact score d'intégration

**Aucun changement** dans `EmployeeOnboardingIntegrationScoreService` ni `EmployeeOnboardingProgressCalculatorService`. Les deux services comptent `completed` — qui représente désormais "validé par le manager" pour les tâches employé. La sémantique est plus correcte qu'avant.

---

## Scope limité

- Seules les tâches `assigned_to_role: 'employee'` utilisent le workflow `pending → done → completed`
- Les tâches `manager` et `hr` conservent `pending → completed` direct (via `complete!` existant, bouton manager dans le show)
- Pas de modification du seed ni des templates d'onboarding

---

## Tests requis

- `OnboardingTask` model : `mark_done!`, `validate!`, `InvalidTransitionError`, invariant `assigned_to_role`
- `OnboardingTaskPolicy` : `validate?`, `mark_done?` avec rôles
- `Manager::EmployeeOnboardingTasksController#validate` : happy path + 422 si not done
- `EmployeeOnboardingTasksController#mark_done` : happy path + 422 si not pending + 422 si assigned_to_role != employee
- Isolation multi-tenant
