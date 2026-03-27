# Admin Org-Wide Schedule View — Design Spec

**Goal:** Allow admin-role employees to consult all weekly schedule plans across the organisation, read-only, accessible from the employee list.

**Architecture:** Two read-only views under `Admin::WeeklySchedulePlansController`. No new policy changes needed — the existing `WeeklySchedulePlanPolicy::Scope` already returns `scope.all` for `hr_or_admin?`. The manager view (`Manager::WeeklySchedulePlansController`) is unchanged.

**Tech Stack:** Rails 7.1, Pundit, Tailwind CSS, Turbo Frames, acts_as_tenant

---

## Access Control

| Role    | Scope                                          | Entry point                          |
|---------|------------------------------------------------|--------------------------------------|
| admin   | All employees in the organisation (org-wide)   | Admin employee list + aggregate view |
| hr      | Employees scoped to their department/manager   | Manager namespace (unchanged)        |
| manager | Their direct team members only                 | Manager namespace (unchanged)        |

No changes to existing manager flows. This spec only adds admin-only read-only views.

---

## Entry Points

### 1. Per-employee link in `_employee.html.erb`

Add a calendar icon link in the actions column of each employee row in `/admin/employees`. Links to the per-employee calendar view: `admin_employee_weekly_schedule_plans_path(employee)`.

Only rendered if the organisation has SIRH plan active (`sirh_plan?`).

### 2. "Voir tous les plannings" button in `admin/employees/index.html.erb`

Add a button in the header action area (next to "Importer CSV" and "Nouvel Employé") linking to the aggregate view: `admin_weekly_schedule_plans_path`.

Only rendered if `sirh_plan?`.

---

## Routes

```ruby
namespace :admin do
  resources :employees  # existing

  # Aggregate: /admin/weekly_schedule_plans?week=YYYY-MM-DD
  resources :weekly_schedule_plans, only: [:index]

  # Per-employee calendar: /admin/employees/:employee_id/weekly_schedule_plans?date=YYYY-MM-DD
  resources :employees do
    resources :weekly_schedule_plans, only: [:index], module: :employees
  end
end
```

The two `resources :employees` blocks merge in Rails — the nested one just adds the sub-resource.

---

## Controllers

### `Admin::WeeklySchedulePlansController`

Handles the **aggregate view** (`/admin/weekly_schedule_plans`).

```ruby
# app/controllers/admin/weekly_schedule_plans_controller.rb
module Admin
  class WeeklySchedulePlansController < BaseController
    def index
      @week_start = parse_week_param || Date.current.beginning_of_week(:monday)
      @week_end   = @week_start + 6.days
      @prev_week  = @week_start - 1.week
      @next_week  = @week_start + 1.week

      @employees = policy_scope(Employee).order(:last_name, :first_name)
      plans = policy_scope(WeeklySchedulePlan)
                .where(week_start_date: @week_start)
                .includes(:employee)
      @plans_by_employee = plans.index_by(&:employee_id)
    end

    private

    def parse_week_param
      params[:week]&.to_date&.beginning_of_week(:monday)
    rescue ArgumentError
      nil
    end
  end
end
```

### `Admin::Employees::WeeklySchedulePlansController`

Handles the **per-employee calendar view** (`/admin/employees/:employee_id/weekly_schedule_plans`).

```ruby
# app/controllers/admin/employees/weekly_schedule_plans_controller.rb
module Admin
  module Employees
    class WeeklySchedulePlansController < Admin::BaseController
      before_action :set_employee

      def index
        @current_date = params[:date]&.to_date || Date.current
        @start_date   = @current_date.beginning_of_month.beginning_of_week(:monday)
        @end_date     = @current_date.end_of_month.end_of_week(:sunday)

        @weekly_plans = policy_scope(WeeklySchedulePlan)
                          .where(employee: @employee)
                          .where(week_start_date: @start_date..@end_date)
                          .index_by(&:week_start_date)

        @calendar_weeks = (@start_date..@end_date).step(7).map { |d| d }
      end

      private

      def set_employee
        @employee = Employee.find(params[:employee_id])
        authorize @employee, :show?
      end
    end
  end
end
```

---

## Views

### Aggregate view — `app/views/admin/weekly_schedule_plans/index.html.erb`

- **Header:** titre "Plannings — Semaine du [lundi] au [dimanche]", navigation prev/next semaine (liens avec `?week=`)
- **Table:** `min-w-full`, une ligne par employé
  - Colonne 1 : avatar + nom (lien vers la vue calendrier de cet employé)
  - Colonnes 2–8 : Lun → Dim. Chaque cellule affiche l'horaire (`09:00-17:00`) ou badge "Repos" si `off`, ou cellule vide si aucun plan
- **Empty state:** si aucun plan pour la semaine, message centré "Aucun planning pour cette semaine"
- Pas de boutons créer/modifier/supprimer

### Per-employee calendar view — `app/views/admin/employees/weekly_schedule_plans/index.html.erb`

Calqué sur `manager/weekly_schedule_plans/index.html.erb` avec :
- Header : nom + avatar de l'employé, navigation mois prev/next
- Grille calendrier mensuelle identique (semaines en lignes, jours en colonnes)
- Badge par semaine : horaires affichés, badge "Non planifié" si aucun plan
- **Aucun lien** vers new/edit/destroy
- Lien retour vers `/admin/employees`

---

## `_employee.html.erb` — ajout du lien planning

Dans la colonne Actions, ajouter avant le bouton supprimer (uniquement si `sirh_plan?`) :

```erb
<% if sirh_plan? %>
  <%= link_to admin_employee_weekly_schedule_plans_path(employee),
      class: "p-2 text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors",
      title: "Plannings" do %>
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
    </svg>
  <% end %>
<% end %>
```

---

## `admin/employees/index.html.erb` — bouton agrégé

Dans le bloc d'actions du header (avant "Importer CSV"), uniquement si `sirh_plan?` :

```erb
<% if sirh_plan? %>
  <%= link_to admin_weekly_schedule_plans_path,
      class: "inline-flex items-center justify-center px-4 py-2 border border-gray-300 dark:border-gray-600 shadow-sm text-sm font-medium rounded-md text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600" do %>
    <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
    </svg>
    Tous les plannings
  <% end %>
<% end %>
```

---

## Multi-tenancy & sécurité

- `acts_as_tenant` est actif sur `Employee` et `WeeklySchedulePlan` → toutes les requêtes sont automatiquement scopées à l'organisation courante
- `policy_scope(Employee)` et `policy_scope(WeeklySchedulePlan)` via Pundit — le scope admin retourne `scope.all` (déjà en place dans `WeeklySchedulePlanPolicy::Scope`)
- `Admin::BaseController#authorize_admin!` garantit que seul un `hr_or_admin?` avec plan actif accède au namespace
- Pas de données cross-tenant possibles

---

## Tests

### `spec/requests/admin/weekly_schedule_plans_controller_spec.rb`
- Accès 200 pour admin
- Redirige (non autorisé) pour manager, employee, non connecté
- Vue agrégée : param `?week=` absent → semaine courante
- Vue agrégée : param `?week=` valide → semaine correcte
- Vue agrégée : affiche les plans de tous les employés de l'orga

### `spec/requests/admin/employees/weekly_schedule_plans_controller_spec.rb`
- Accès 200 pour admin
- Redirige pour manager, employee
- Param `?date=` absent → mois courant
- Param `?date=` valide → mois correct
- Affiche uniquement les plans de l'employé demandé
