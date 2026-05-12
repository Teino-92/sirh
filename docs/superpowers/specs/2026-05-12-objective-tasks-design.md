# Objective Tasks — Design Spec

**Date:** 2026-05-12
**Statut:** Approuvé

---

## Résumé

Chaque objectif peut avoir une liste de tâches concrètes qui font progresser sa completion. Le manager crée et valide les tâches. Le membre de l'équipe les marque comme faites. La progression de l'objectif est calculée sur les tâches validées.

---

## Modèle de données

### Table `objective_tasks`

| Colonne | Type | Contraintes |
|---|---|---|
| `id` | bigint | PK |
| `organization_id` | bigint | FK, NOT NULL |
| `objective_id` | bigint | FK, NOT NULL |
| `title` | string(255) | NOT NULL |
| `description` | text | nullable |
| `deadline` | date | nullable |
| `assigned_to_id` | bigint | FK → employees, NOT NULL |
| `status` | string | NOT NULL, default: `todo` |
| `completed_at` | datetime | nullable |
| `completed_by_id` | bigint | FK → employees, nullable |
| `validated_at` | datetime | nullable |
| `validated_by_id` | bigint | FK → employees, nullable |
| `position` | integer | NOT NULL, default: 0 |
| `created_at` / `updated_at` | datetime | |

**Index :** `(organization_id, objective_id)`, `(assigned_to_id)`, `(status)`

### Enum `status`
- `todo` — créée, pas encore traitée
- `done` — membre a marqué comme faite, en attente de validation manager
- `validated` — manager a validé

### Modèle `ObjectiveTask`

```ruby
# app/domains/objectives/models/objective_task.rb
class ObjectiveTask < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization
  belongs_to :objective
  belongs_to :assigned_to, class_name: 'Employee'
  belongs_to :completed_by, class_name: 'Employee', optional: true
  belongs_to :validated_by, class_name: 'Employee', optional: true

  enum status: { todo: 'todo', done: 'done', validated: 'validated' }

  validates :title, presence: true, length: { maximum: 255 }
  validates :assigned_to, presence: true
  validate_same_organization :objective
  validate_same_organization :assigned_to

  default_scope { order(:position) }

  def complete!(employee)
    raise "already validated" if validated?
    update!(status: :done, completed_at: Time.current, completed_by: employee)
  end

  def validate!(manager)
    raise "not done yet" unless done?
    update!(status: :validated, validated_at: Time.current, validated_by: manager)
  end
end
```

### Modifications `Objective`

```ruby
has_many :objective_tasks, dependent: :destroy

def progress_percentage
  return nil if objective_tasks.empty?
  validated = objective_tasks.validated.count
  total = objective_tasks.count
  (validated.to_f / total * 100).round
end

def tasks?
  objective_tasks.any?
end
```

---

## Architecture

### Controllers

**`Manager::ObjectiveTasksController`**
- `create` — crée une tâche sur un objectif du manager
- `destroy` — supprime si non validée
- `validate` (PATCH member) — valide une tâche `done`

**`ObjectiveTasksController`** (employee)
- `complete` (PATCH member) — marque une tâche assignée comme `done`

### Routes

```ruby
# Manager
namespace :manager do
  resources :objectives do
    resources :objective_tasks, only: [:create, :destroy] do
      member { patch :validate }
    end
  end
end

# Employee
resources :objectives, only: [:index, :show] do
  resources :objective_tasks, only: [] do
    member { patch :complete }
  end
end
```

### Vues

**`manager/objectives/show`** — section "Tâches" ajoutée :
- Turbo Frame `objective_tasks_<objective_id>`
- Formulaire inline "Ajouter une tâche" (titre, description, deadline, assigné)
- Liste des tâches avec badge statut, bouton "Valider" si `done`
- Barre de progression basée sur `progress_percentage` si tâches présentes

**`objectives/show`** (employee) — section "Mes tâches" :
- Tâches assignées à cet employé
- Bouton "Marquer comme fait" sur tâches `todo`
- Lecture seule sur les autres tâches

---

## Sécurité

### Pundit `ObjectiveTaskPolicy`

| Action | Manager | Employee |
|---|---|---|
| `create?` | Oui, si manager de l'objectif | Non |
| `destroy?` | Oui, si non validée | Non |
| `validate?` | Oui, si tâche `done` et manager de l'objectif | Non |
| `complete?` | Non | Oui, si `assigned_to == current_employee` et `todo` |

### Invariants

- `validate` → 422 si tâche pas `done`
- `complete` → 422 si tâche déjà `validated`
- `destroy` → 422 si tâche `validated`
- `completed_by` forcé = `current_employee` (pas manipulable via params)
- `validated_by` forcé = `current_employee` (pas manipulable via params)
- Multi-tenancy : `acts_as_tenant :organization` + `validate_same_organization`
- Cascade : `dependent: :destroy` sur `objective.objective_tasks`

---

## Progression objectif

- Si `objective_tasks.empty?` → affiche progression temporelle (comportement actuel)
- Sinon → `progress_percentage = validated / total * 100`
- Affiché sur `index` et `show` manager + employee

---

## Tests requis

- `ObjectiveTask` model : validations, `complete!`, `validate!`, invariants
- `Manager::ObjectiveTasksController` : create/destroy/validate avec Pundit
- `ObjectiveTasksController` : complete avec Pundit
- Isolation multi-tenant : pas d'accès cross-org
- `Objective#progress_percentage` : 0 tâches, partial, 100%
