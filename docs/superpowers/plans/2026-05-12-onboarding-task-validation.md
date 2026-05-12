# Onboarding Task Validation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter un workflow `pending → done → completed` sur les tâches d'onboarding assignées à l'employé — l'employé marque comme fait, le manager valide — sans impacter le score d'intégration ni les tâches manager/hr.

**Architecture:** Migration pour ajouter `done` à l'enum + colonnes `validated_at`/`validated_by_id`. Méthodes `mark_done!` et `validate!` sur `OnboardingTask`. Nouveau controller employee `EmployeeOnboardingTasksController`, action `validate` sur le controller manager existant. Vues turbo stream sur les deux show pages.

**Tech Stack:** Rails 7.1, Turbo Streams, Pundit, RSpec + FactoryBot, acts_as_tenant

---

## Structure des fichiers

**Créer :**
- `db/migrate/TIMESTAMP_add_done_status_to_onboarding_tasks.rb`
- `app/controllers/employee_onboarding_tasks_controller.rb`
- `app/views/manager/employee_onboarding_tasks/validate.turbo_stream.erb`
- `app/views/employee_onboarding_tasks/mark_done.turbo_stream.erb`
- `spec/models/onboarding_task_spec.rb` (nouveau ou compléter l'existant)

**Modifier :**
- `app/domains/onboarding/models/onboarding_task.rb` — enum + méthodes + erreur typée
- `app/policies/onboarding_task_policy.rb` — ajouter `validate?` et `mark_done?`
- `app/controllers/manager/employee_onboarding_tasks_controller.rb` — ajouter action `validate`
- `config/routes.rb` — ajouter `validate` (manager) + route employee `mark_done`
- `app/views/manager/employee_onboardings/show.html.erb` — badge + bouton valider
- `app/views/employee_onboardings/show.html.erb` — bouton marquer fait
- `spec/factories/onboardings.rb` — traits `:done` sur `onboarding_task`
- `spec/policies/onboarding_task_policy_spec.rb` (créer)

---

## Task 1 : Migration + modèle

**Files :**
- Create: `db/migrate/TIMESTAMP_add_done_status_to_onboarding_tasks.rb`
- Modify: `app/domains/onboarding/models/onboarding_task.rb`
- Modify: `spec/factories/onboardings.rb`
- Create: `spec/models/onboarding_task_spec.rb`

- [ ] **Step 1 : Écrire le spec modèle (failing)**

```ruby
# spec/models/onboarding_task_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTask, type: :model do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, :manager, organization: org) }
  let(:employee) { create(:employee, organization: org) }
  let(:onboarding) do
    ActsAsTenant.with_tenant(org) do
      create(:employee_onboarding, organization: org, employee: employee, manager: manager)
    end
  end

  subject(:task) do
    ActsAsTenant.with_tenant(org) do
      build(:onboarding_task, organization: org, employee_onboarding: onboarding,
            assigned_to_role: 'employee', status: 'pending')
    end
  end

  describe '#mark_done!' do
    it 'transitions pending → done' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.mark_done!(employee)
        expect(task.reload.status).to eq('done')
        expect(task.completed_by_id).to eq(employee.id)
        expect(task.completed_at).to be_present
      end
    end

    it 'raises if already completed' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'completed')
        expect { task.mark_done!(employee) }.to raise_error(OnboardingTask::InvalidTransitionError, /déjà complétée/)
      end
    end

    it 'raises if assigned_to_role is not employee' do
      ActsAsTenant.with_tenant(org) do
        manager_task = build(:onboarding_task, organization: org,
                             employee_onboarding: onboarding, assigned_to_role: 'manager')
        manager_task.save!
        expect { manager_task.mark_done!(employee) }.to raise_error(OnboardingTask::InvalidTransitionError, /assigned_to_role/)
      end
    end
  end

  describe '#validate!' do
    it 'transitions done → completed' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        task.update_columns(status: 'done')
        task.validate!(manager)
        expect(task.reload.status).to eq('completed')
        expect(task.validated_at).to be_present
        expect(task.validated_by_id).to eq(manager.id)
      end
    end

    it 'raises if not done' do
      ActsAsTenant.with_tenant(org) do
        task.save!
        expect { task.validate!(manager) }.to raise_error(OnboardingTask::InvalidTransitionError, /doit être done/)
      end
    end
  end
end
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && bundle exec rspec spec/models/onboarding_task_spec.rb --no-color 2>&1 | head -10
```
Expected: erreur sur `mark_done!` undefined

- [ ] **Step 3 : Créer la migration**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && rails generate migration AddDoneStatusAndValidationToOnboardingTasks
```

Éditer le fichier généré dans `db/migrate/` :

```ruby
class AddDoneStatusAndValidationToOnboardingTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :onboarding_tasks, :validated_at, :datetime
    add_column :onboarding_tasks, :validated_by_id, :bigint
    add_foreign_key :onboarding_tasks, :employees, column: :validated_by_id

    # Mettre à jour l'index partiel qui ne cible que 'pending'
    # pour inclure aussi 'done' (tâches actives)
    remove_index :onboarding_tasks, name: "idx_onboarding_tasks_org_pending_due"
    add_index :onboarding_tasks, [:organization_id, :due_date],
              name: "idx_onboarding_tasks_org_active_due",
              where: "(status IN ('pending', 'done'))"
  end
end
```

- [ ] **Step 4 : Lancer la migration**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && rails db:migrate
```
Expected: `AddDoneStatusAndValidationToOnboardingTasks: migrated`

- [ ] **Step 5 : Modifier le modèle OnboardingTask**

Fichier complet `app/domains/onboarding/models/onboarding_task.rb` :

```ruby
# frozen_string_literal: true

class OnboardingTask < ApplicationRecord
  belongs_to :employee_onboarding, foreign_key: :employee_onboarding_id
  belongs_to :organization
  acts_as_tenant :organization

  belongs_to :assigned_to,  class_name: 'Employee', optional: true, foreign_key: :assigned_to_id
  belongs_to :completed_by, class_name: 'Employee', optional: true, foreign_key: :completed_by_id
  belongs_to :validated_by, class_name: 'Employee', optional: true, foreign_key: :validated_by_id

  class InvalidTransitionError < StandardError; end

  TASK_TYPES     = OnboardingTemplateTask::TASK_TYPES
  ASSIGNED_ROLES = OnboardingTemplateTask::ASSIGNED_ROLES

  enum status: {
    pending:   'pending',
    done:      'done',
    completed: 'completed',
    overdue:   'overdue'
  }

  validates :title,            presence: true, length: { maximum: 255 }
  validates :due_date,         presence: true
  validates :assigned_to_role, inclusion: { in: ASSIGNED_ROLES }
  validates :task_type,        inclusion: { in: TASK_TYPES }

  scope :pending,              -> { where(status: 'pending') }
  scope :done,                 -> { where(status: 'done') }
  scope :completed,            -> { where(status: 'completed') }
  scope :overdue,              -> { where(status: 'pending').where('due_date < ?', Date.current) }
  scope :awaiting_validation,  -> { where(status: 'done') }

  # Appelée par l'employé — uniquement tâches assigned_to_role: 'employee'
  def mark_done!(employee)
    raise InvalidTransitionError, "seules les tâches assigned_to_role 'employee' peuvent être marquées faites" unless assigned_to_role == 'employee'
    raise InvalidTransitionError, "déjà complétée" if completed?
    update!(status: :done, completed_at: Time.current, completed_by: employee)
  end

  # Appelée par le manager — valide une tâche done
  def validate!(manager)
    raise InvalidTransitionError, "la tâche doit être done avant validation" unless done?
    update!(status: :completed, validated_at: Time.current, validated_by: manager)
  end

  # Comportement historique — utilisé pour tâches manager/hr (complétion directe)
  def complete!(completed_by:)
    return if completed?

    transaction do
      update!(
        status:       :completed,
        completed_at: Time.current,
        completed_by: completed_by
      )
    end
  end

  def overdue?
    pending? && due_date < Date.current
  end

  def linked_record
    case task_type
    when 'objective_30', 'objective_60', 'objective_90'
      id = metadata['linked_objective_id']
      Objective.find_by(id: id) if id
    when 'training'
      id = metadata['linked_training_assignment_id']
      TrainingAssignment.find_by(id: id) if id
    when 'one_on_one'
      id = metadata['linked_one_on_one_id']
      OneOnOne.find_by(id: id) if id
    end
  end
end
```

- [ ] **Step 6 : Ajouter les traits factory**

Dans `spec/factories/onboardings.rb`, dans le bloc `factory :onboarding_task`, ajouter après le trait `:completed` existant :

```ruby
trait :done do
  status       { 'done' }
  assigned_to_role { 'employee' }
  completed_at { 1.day.ago }
  completed_by { association(:employee, organization: organization) }
end

trait :employee_task do
  assigned_to_role { 'employee' }
end
```

- [ ] **Step 7 : Lancer les tests**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && bundle exec rspec spec/models/onboarding_task_spec.rb --no-color 2>&1 | grep -E "examples|failures"
```
Expected: `5 examples, 0 failures`

- [ ] **Step 8 : Commit**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh
git add db/migrate/*_add_done_status_and_validation_to_onboarding_tasks.rb \
        db/schema.rb \
        app/domains/onboarding/models/onboarding_task.rb \
        spec/models/onboarding_task_spec.rb \
        spec/factories/onboardings.rb
git commit -m "feat(onboarding): add done status + mark_done!/validate! workflow to OnboardingTask"
```

---

## Task 2 : Policy

**Files :**
- Modify: `app/policies/onboarding_task_policy.rb`
- Create: `spec/policies/onboarding_task_policy_spec.rb`

- [ ] **Step 1 : Écrire le spec policy (failing)**

```ruby
# spec/policies/onboarding_task_policy_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTaskPolicy, type: :policy do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, :manager, organization: org) }
  let(:employee) { create(:employee, organization: org) }
  let(:other_emp){ create(:employee, organization: org) }

  let(:onboarding) do
    ActsAsTenant.with_tenant(org) do
      create(:employee_onboarding, organization: org, employee: employee, manager: manager)
    end
  end

  let(:pending_emp_task) do
    ActsAsTenant.with_tenant(org) do
      create(:onboarding_task, :employee_task, organization: org,
             employee_onboarding: onboarding, status: 'pending')
    end
  end

  let(:done_emp_task) do
    ActsAsTenant.with_tenant(org) do
      create(:onboarding_task, :done, organization: org, employee_onboarding: onboarding)
    end
  end

  let(:completed_task) do
    ActsAsTenant.with_tenant(org) do
      create(:onboarding_task, :completed, organization: org, employee_onboarding: onboarding)
    end
  end

  describe 'manager permissions' do
    describe 'validate?' do
      it 'permits manager of onboarding when task is done' do
        policy = described_class.new(manager, done_emp_task)
        expect(policy.validate?).to be true
      end

      it 'denies when task is not done' do
        policy = described_class.new(manager, pending_emp_task)
        expect(policy.validate?).to be false
      end

      it 'denies employee' do
        policy = described_class.new(employee, done_emp_task)
        expect(policy.validate?).to be false
      end
    end

    describe 'update?' do
      it 'permits manager of onboarding' do
        policy = described_class.new(manager, pending_emp_task)
        expect(policy.update?).to be true
      end
    end
  end

  describe 'employee permissions' do
    describe 'mark_done?' do
      it 'permits assigned employee on pending task' do
        policy = described_class.new(employee, pending_emp_task)
        expect(policy.mark_done?).to be true
      end

      it 'denies if task not pending' do
        policy = described_class.new(employee, done_emp_task)
        expect(policy.mark_done?).to be false
      end

      it 'denies if assigned_to_role != employee' do
        manager_task = ActsAsTenant.with_tenant(org) do
          create(:onboarding_task, organization: org,
                 employee_onboarding: onboarding, assigned_to_role: 'manager', status: 'pending')
        end
        policy = described_class.new(employee, manager_task)
        expect(policy.mark_done?).to be false
      end

      it 'denies other employee' do
        policy = described_class.new(other_emp, pending_emp_task)
        expect(policy.mark_done?).to be false
      end
    end
  end
end
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && bundle exec rspec spec/policies/onboarding_task_policy_spec.rb --no-color 2>&1 | head -10
```
Expected: `NoMethodError` sur `validate?` ou `mark_done?`

- [ ] **Step 3 : Modifier la policy**

Fichier complet `app/policies/onboarding_task_policy.rb` :

```ruby
# frozen_string_literal: true

class OnboardingTaskPolicy < ApplicationPolicy
  def update?
    hr_admin? || manager_of_onboarding?
  end

  def validate?
    return false unless record.done?
    manager_of_onboarding?
  end

  def mark_done?
    return false unless record.pending?
    return false unless record.assigned_to_role == 'employee'
    user == record.employee_onboarding.employee
  end

  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.joins(:employee_onboarding)
             .where(employee_onboardings: { manager_id: user.id })
      else
        scope.joins(:employee_onboarding)
             .where(employee_onboardings: { employee_id: user.id })
      end
    end
  end

  private

  def hr_admin?
    user.hr_or_admin?
  end

  def manager_of_onboarding?
    user.manager? && record.employee_onboarding.manager_id == user.id
  end
end
```

- [ ] **Step 4 : Lancer les tests**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && bundle exec rspec spec/policies/onboarding_task_policy_spec.rb --no-color 2>&1 | grep -E "examples|failures"
```
Expected: `9 examples, 0 failures`

- [ ] **Step 5 : Commit**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh
git add app/policies/onboarding_task_policy.rb spec/policies/onboarding_task_policy_spec.rb
git commit -m "feat(onboarding): add validate? and mark_done? to OnboardingTaskPolicy"
```

---

## Task 3 : Routes

**Files :**
- Modify: `config/routes.rb`

- [ ] **Step 1 : Modifier les routes manager**

Dans `config/routes.rb`, ligne ~177, remplacer :

```ruby
resources :employee_onboarding_tasks, only: [:update], shallow: true
```

Par :

```ruby
resources :employee_onboarding_tasks, only: [:update], shallow: true do
  member do
    patch :validate
  end
end
```

- [ ] **Step 2 : Ajouter les routes employee**

Dans `config/routes.rb`, à la ligne ~104 où se trouve `resources :employee_onboardings, only: [:show]`, remplacer par :

```ruby
resources :employee_onboardings, only: [:show] do
  resources :employee_onboarding_tasks, only: [] do
    member do
      patch :mark_done
    end
  end
end
```

- [ ] **Step 3 : Vérifier les routes**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && rails routes | grep onboarding_task 2>&1
```

Expected (extrait clé) :
```
validate_employee_onboarding_task  PATCH  /manager/employee_onboardings/:employee_onboarding_id/employee_onboarding_tasks/:id/validate
mark_done_employee_onboarding_employee_onboarding_task  PATCH  /employee_onboardings/:employee_onboarding_id/employee_onboarding_tasks/:id/mark_done
```

- [ ] **Step 4 : Commit**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh
git add config/routes.rb
git commit -m "feat(onboarding): add validate (manager) and mark_done (employee) routes"
```

---

## Task 4 : Controllers

**Files :**
- Modify: `app/controllers/manager/employee_onboarding_tasks_controller.rb`
- Create: `app/controllers/employee_onboarding_tasks_controller.rb`

- [ ] **Step 1 : Ajouter action `validate` au controller manager**

Fichier complet `app/controllers/manager/employee_onboarding_tasks_controller.rb` :

```ruby
# frozen_string_literal: true

module Manager
  class EmployeeOnboardingTasksController < BaseController

    def update
      @task = current_organization.onboarding_tasks.includes(:employee_onboarding).find(params[:id])
      authorize @task

      onboarding = @task.employee_onboarding
      raise ActiveRecord::RecordNotFound, "Onboarding introuvable pour cette tâche" if onboarding.nil?

      @task.complete!(completed_by: current_employee)
      EmployeeOnboardingScoreRefreshJob.perform_later(onboarding.id)
      fire_rules_engine('onboarding.task_completed', @task, {
        'task_type'        => @task.task_type.to_s,
        'assigned_to_role' => @task.assigned_to_role.to_s,
        'onboarding_day'   => onboarding.day_number.to_i
      })

      respond_to do |format|
        format.html { redirect_to manager_employee_onboarding_path(onboarding), notice: 'Tâche complétée.' }
        format.turbo_stream
      end
    end

    def validate
      @task = current_organization.onboarding_tasks.includes(:employee_onboarding).find(params[:id])
      authorize @task, :validate?

      @onboarding = @task.employee_onboarding
      @task.validate!(current_employee)
      EmployeeOnboardingScoreRefreshJob.perform_later(@onboarding.id)

      respond_to do |format|
        format.html { redirect_to manager_employee_onboarding_path(@onboarding), notice: 'Tâche validée.' }
        format.turbo_stream
      end
    rescue OnboardingTask::InvalidTransitionError => e
      respond_to do |format|
        format.html { redirect_to manager_employee_onboarding_path(@task.employee_onboarding), alert: e.message }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end
end
```

- [ ] **Step 2 : Créer le controller employee**

```ruby
# app/controllers/employee_onboarding_tasks_controller.rb
# frozen_string_literal: true

class EmployeeOnboardingTasksController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_onboarding
  before_action :set_task

  def mark_done
    authorize @task, :mark_done?
    @task.mark_done!(current_employee)

    respond_to do |format|
      format.html { redirect_to employee_onboarding_path(@onboarding), notice: 'Tâche marquée comme faite.' }
      format.turbo_stream
    end
  rescue OnboardingTask::InvalidTransitionError => e
    respond_to do |format|
      format.html { redirect_to employee_onboarding_path(@onboarding), alert: e.message }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  private

  def set_onboarding
    @onboarding = current_organization.employee_onboardings.find(params[:employee_onboarding_id])
  end

  def set_task
    @task = @onboarding.onboarding_tasks.find(params[:id])
  end
end
```

- [ ] **Step 3 : Vérifier la syntaxe**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh && bundle exec rails runner "Manager::EmployeeOnboardingTasksController; EmployeeOnboardingTasksController" 2>&1 | head -5
```
Expected: aucune erreur

- [ ] **Step 4 : Commit**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh
git add app/controllers/manager/employee_onboarding_tasks_controller.rb \
        app/controllers/employee_onboarding_tasks_controller.rb
git commit -m "feat(onboarding): add validate (manager) and mark_done (employee) controller actions"
```

---

## Task 5 : Turbo streams + vues

**Files :**
- Create: `app/views/manager/employee_onboarding_tasks/` (dossier + fichiers)
- Create: `app/views/employee_onboarding_tasks/mark_done.turbo_stream.erb`
- Modify: `app/views/manager/employee_onboardings/show.html.erb`
- Modify: `app/views/employee_onboardings/show.html.erb`

### 5a — Turbo streams manager

- [ ] **Step 1 : Créer le dossier et le turbo stream validate**

```bash
mkdir -p /Users/matteogarbugli/code/Teino-92/easy-rh/app/views/manager/employee_onboarding_tasks
```

`app/views/manager/employee_onboarding_tasks/validate.turbo_stream.erb` :

```erb
<%= turbo_stream.replace "onboarding_task_#{@task.id}" do %>
  <%= render 'manager/employee_onboardings/task_row', task: @task, onboarding: @onboarding %>
<% end %>
```

### 5b — Partial tâche manager `_task_row.html.erb`

- [ ] **Step 2 : Créer le partial `_task_row.html.erb`**

Actuellement la vue manager/show inline les tâches. Il faut extraire la ligne en partial pour le turbo stream.

Créer `app/views/manager/employee_onboardings/_task_row.html.erb` :

```erb
<%# locals: (task:, onboarding:) %>
<div id="onboarding_task_<%= task.id %>"
     class="flex items-start gap-3 p-3 rounded-lg <%= task.completed? ? 'bg-green-50 dark:bg-green-900/10' : task.status == 'done' ? 'bg-warning/5 dark:bg-warning/5' : task.overdue? ? 'bg-red-50 dark:bg-red-900/10' : 'bg-bg-soft dark:bg-surface/10' %>">
  <%
    type_icons = {
      'manual'       => '✓',
      'objective_30' => '🎯', 'objective_60' => '🎯', 'objective_90' => '🎯',
      'training'     => '📚',
      'one_on_one'   => '💬'
    }
  %>

  <div class="flex-shrink-0 mt-0.5">
    <% if task.completed? %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full bg-success">
        <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
        </svg>
      </span>
    <% elsif task.status == 'done' %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full bg-warning/20">
        <svg class="w-3 h-3 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </span>
    <% elsif task.overdue? %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full bg-red-400">
        <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/>
        </svg>
      </span>
    <% else %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full border-2 border-border-soft dark:border-white/10"></span>
    <% end %>
  </div>

  <div class="flex-1 min-w-0">
    <p class="text-sm font-medium <%= task.completed? ? 'line-through text-muted-soft dark:text-white/40' : 'text-text-deep dark:text-white' %>">
      <%= type_icons[task.task_type] %> <%= task.title %>
    </p>
    <% if task.description.present? %>
      <p class="text-xs text-muted-soft dark:text-white/50 mt-0.5"><%= task.description %></p>
    <% end %>
    <div class="flex items-center gap-3 mt-1 flex-wrap">
      <span class="text-xs text-muted-soft dark:text-white/50"><%= l(task.due_date, format: :short) %></span>
      <% if task.status == 'done' %>
        <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-warning/10 text-warning">
          À valider
        </span>
        <% if task.completed_at.present? %>
          <span class="text-xs text-muted-soft dark:text-white/40">
            Fait le <%= l(task.completed_at.to_date, format: :short) %>
            <% if task.completed_by.present? %>par <%= task.completed_by.full_name %><% end %>
          </span>
        <% end %>
      <% end %>
      <% if task.completed? && task.validated_at.present? %>
        <span class="text-xs text-muted-soft dark:text-white/40">
          Validé le <%= l(task.validated_at.to_date, format: :short) %>
        </span>
      <% end %>
    </div>
  </div>

  <div class="flex-shrink-0 flex items-center gap-1">
    <% if task.status == 'done' %>
      <%= button_to validate_employee_onboarding_task_path(task),
            method: :patch,
            class: "inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-medium text-white bg-success hover:bg-success/90 transition-colors border-0 cursor-pointer",
            data: { turbo_stream: true } do %>
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/>
        </svg>
        Valider
      <% end %>
    <% elsif task.pending? && task.assigned_to_role != 'employee' %>
      <%= button_to manager_employee_onboarding_task_path(task), method: :patch,
            class: "inline-flex items-center px-2.5 py-1 rounded-md text-xs font-medium text-white bg-primary hover:bg-primary/90 transition-colors border-0 cursor-pointer",
            data: { turbo_stream: true } do %>
        Compléter
      <% end %>
    <% end %>
  </div>
</div>
```

### 5c — Mettre à jour manager/show pour utiliser le partial

- [ ] **Step 3 : Mettre à jour la vue manager show**

Dans `app/views/manager/employee_onboardings/show.html.erb`, trouver la boucle qui rend les tâches (autour de la ligne 134) :

```erb
<% tasks.each do |task| %>
```

Remplacer le bloc `<div>` inline de chaque tâche par le partial. La boucle actuelle ressemble à :

```erb
<% tasks.each do |task| %>
  <div class="flex items-start gap-3 p-3 rounded-lg ...">
    ...beaucoup de code inline...
  </div>
<% end %>
```

Remplacer le contenu de la boucle par :

```erb
<% tasks.each do |task| %>
  <%= render 'manager/employee_onboardings/task_row', task: task, onboarding: @employee_onboarding %>
<% end %>
```

**Attention :** Lis d'abord le fichier entier pour identifier exactement les lignes de début et fin du bloc tâche inline à remplacer.

### 5d — Turbo stream employee mark_done

- [ ] **Step 4 : Créer le dossier et turbo stream mark_done**

```bash
mkdir -p /Users/matteogarbugli/code/Teino-92/easy-rh/app/views/employee_onboarding_tasks
```

`app/views/employee_onboarding_tasks/mark_done.turbo_stream.erb` :

```erb
<%= turbo_stream.replace "onboarding_task_emp_#{@task.id}" do %>
  <%= render 'employee_onboardings/task_row', task: @task, onboarding: @onboarding %>
<% end %>
```

### 5e — Partial tâche employee `_task_row.html.erb`

- [ ] **Step 5 : Créer le partial employee**

Créer `app/views/employee_onboardings/_task_row.html.erb` :

```erb
<%# locals: (task:, onboarding:) %>
<div id="onboarding_task_emp_<%= task.id %>"
     class="flex items-start gap-3 p-3 rounded-lg <%= task.completed? ? 'bg-green-50 dark:bg-green-900/10' : task.status == 'done' ? 'bg-warning/5' : task.overdue? ? 'bg-red-50 dark:bg-red-900/10' : 'bg-bg-soft dark:bg-surface/10' %>">
  <%
    type_icons = {
      'manual'       => '✓',
      'objective_30' => '🎯', 'objective_60' => '🎯', 'objective_90' => '🎯',
      'training'     => '📚',
      'one_on_one'   => '💬'
    }
  %>
  <div class="flex-shrink-0 mt-0.5">
    <% if task.completed? %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full bg-green-500">
        <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
        </svg>
      </span>
    <% elsif task.status == 'done' %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full bg-warning/20">
        <svg class="w-3 h-3 text-warning" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </span>
    <% elsif task.overdue? %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full bg-red-400">
        <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd"/>
        </svg>
      </span>
    <% else %>
      <span class="w-5 h-5 flex items-center justify-center rounded-full border-2 border-border-soft dark:border-white/10"></span>
    <% end %>
  </div>

  <div class="flex-1 min-w-0">
    <p class="text-sm font-medium <%= task.completed? ? 'line-through text-muted-soft dark:text-white/40' : 'text-text-deep dark:text-white' %>">
      <%= type_icons[task.task_type] %> <%= task.title %>
    </p>
    <% if task.description.present? %>
      <p class="text-xs text-muted-soft dark:text-white/50 mt-0.5"><%= task.description %></p>
    <% end %>
    <% linked = task.linked_record rescue nil %>
    <% if linked %>
      <p class="text-xs text-primary dark:text-primary/80 mt-1">
        Associé : <%= linked.try(:title) || linked.try(:name) %>
      </p>
    <% end %>
    <div class="flex items-center gap-3 mt-1 flex-wrap">
      <span class="text-xs <%= task.overdue? && task.pending? ? 'text-red-600 dark:text-red-400 font-medium' : 'text-muted-soft dark:text-white/50' %>">
        <%= l(task.due_date, format: :short) %>
      </span>
      <% if task.status == 'done' %>
        <span class="text-xs text-warning">En attente de validation manager</span>
      <% end %>
      <% if task.completed? && task.validated_by.present? %>
        <span class="text-xs text-success">Validé par <%= task.validated_by.full_name %></span>
      <% end %>
    </div>
  </div>

  <div class="flex-shrink-0">
    <% if task.pending? && task.assigned_to_role == 'employee' %>
      <%= button_to mark_done_employee_onboarding_employee_onboarding_task_path(onboarding, task),
            method: :patch,
            class: "inline-flex items-center px-2.5 py-1 rounded-md text-xs font-medium text-white bg-primary hover:bg-primary/90 transition-colors border-0 cursor-pointer",
            data: { turbo_stream: true } do %>
        Marquer fait
      <% end %>
    <% end %>
  </div>
</div>
```

### 5f — Mettre à jour employee/show pour utiliser le partial

- [ ] **Step 6 : Mettre à jour la vue employee show**

Dans `app/views/employee_onboardings/show.html.erb`, trouver la boucle `my_tasks.each` (autour de la ligne 63) qui rend chaque tâche inline. Remplacer le bloc `<div>` inline par le partial :

```erb
<% my_tasks.each do |task| %>
  <%= render 'employee_onboardings/task_row', task: task, onboarding: @employee_onboarding %>
<% end %>
```

**Attention :** Lis d'abord le fichier pour identifier exactement les lignes de début/fin du bloc inline à remplacer.

- [ ] **Step 7 : Commit**

```bash
cd /Users/matteogarbugli/code/Teino-92/easy-rh
git add app/views/manager/employee_onboarding_tasks/ \
        app/views/manager/employee_onboardings/_task_row.html.erb \
        app/views/manager/employee_onboardings/show.html.erb \
        app/views/employee_onboarding_tasks/ \
        app/views/employee_onboardings/_task_row.html.erb \
        app/views/employee_onboardings/show.html.erb
git commit -m "feat(onboarding): turbo stream validate/mark_done + extract task_row partials"
```

---

## Self-Review

**Spec coverage :**
- ✅ `done` status + migration colonnes `validated_at`/`validated_by_id` — Task 1
- ✅ `mark_done!` employee + guard `assigned_to_role` — Task 1
- ✅ `validate!` manager + guard `done?` — Task 1
- ✅ `complete!` historique préservé — Task 1
- ✅ `InvalidTransitionError` typée — Task 1
- ✅ `OnboardingTaskPolicy#validate?` + `mark_done?` — Task 2
- ✅ Routes `validate` (manager shallow) + `mark_done` (employee nested) — Task 3
- ✅ `Manager::EmployeeOnboardingTasksController#validate` — Task 4
- ✅ `EmployeeOnboardingTasksController#mark_done` — Task 4
- ✅ Turbo streams + partials + vues modifiées — Task 5
- ✅ Score d'intégration inchangé (compte `completed`) — pas de task nécessaire
- ✅ Multi-tenant : `current_organization` scopé dans les deux controllers

**Placeholders :** aucun.

**Cohérence types :**
- `mark_done!` / `validate!` / `complete!` — cohérents entre modèle, controllers, policy
- `onboarding_task_<id>` (manager) / `onboarding_task_emp_<id>` (employee) — IDs distincts cohérents entre partials et turbo streams
- `validate_employee_onboarding_task_path(task)` — shallow route, prend juste `task` (pas `onboarding`)
- `mark_done_employee_onboarding_employee_onboarding_task_path(onboarding, task)` — nested route, prend les deux
