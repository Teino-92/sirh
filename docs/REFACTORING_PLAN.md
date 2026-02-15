# Plan de Refactorisation - Easy-RH

**Date**: 2026-01-13
**Status**: En cours - Phases 1 & 2 terminées
**Objectif**: Améliorer la maintenabilité, les performances et la structure du code sans rien casser

## Table des Matières

- [Travail Déjà Effectué](#travail-déjà-effectué)
- [Frontend - Refactorisation Restante](#frontend---refactorisation-restante)
- [Backend - Opportunités de Refactorisation](#backend---opportunités-de-refactorisation)
  - [Critique (À faire en priorité)](#critique-à-faire-en-priorité)
  - [Haute Priorité](#haute-priorité)
  - [Moyenne Priorité](#moyenne-priorité)
  - [Basse Priorité](#basse-priorité)
- [Roadmap d'Implémentation](#roadmap-dimplémentation)

---

## Travail Déjà Effectué

### Phase 1: Extraction Dark Mode & Flash Messages
✅ **Terminé**
- Créé `_dark_mode_init.html.erb` - Initialisation du thème
- Créé `_dark_mode_toggle.html.erb` - Toggle utilisateur
- Créé `_flash_messages.html.erb` - Messages système
- **Résultat**: ~50 lignes dupliquées éliminées

### Phase 2: Composants Navigation & Cartes
✅ **Terminé**
- Créé `_mobile_nav_item.html.erb` - Navigation mobile bottom bar
- Créé `_desktop_nav_link.html.erb` - Navigation desktop top bar
- Créé `_card_section.html.erb` - Conteneur carte réutilisable
- Créé `_leave_balance_card.html.erb` - Carte solde de congés
- **Résultat**: ~100 lignes dupliquées éliminées

### Bug Fix Critique
✅ **Résolu** - `LeaveRequest#conflicts_with_team?`
- **Problème**: `NoMethodError: undefined method 'not' for nil`
- **Cause**: Chaîne `&.` retournant nil pour employés sans manager
- **Solution**: Guard clause explicite `return false unless employee.manager`
- **Fichier**: `app/domains/leave_management/models/leave_request.rb:61-70`

---

## Frontend - Refactorisation Restante

### Phase 3: Application des Partials Card (19 Vues)

**Effort**: Medium (4-6h)
**Risque**: Safe
**Gain**: ~200 lignes éliminées, cohérence visuelle améliorée

#### Vues à Refactoriser

| Fichier | Pattern Trouvé | Action |
|---------|----------------|--------|
| `time_entries/index.html.erb` | `bg-white dark:bg-gray-800 rounded-lg shadow` | Remplacer par `_card_section` |
| `leave_requests/index.html.erb` | Multiples cartes | Utiliser `_card_section` |
| `leave_requests/new.html.erb` | Formulaire carte | Wrapper `_card_section` |
| `leave_requests/pending_approvals.html.erb` | Liste cartes | Appliquer `_card_section` |
| `leave_requests/team_calendar.html.erb` | Grille cartes | Standardiser avec `_card_section` |
| `work_schedules/show.html.erb` | Carte planning | Utiliser `_card_section` |
| `profile/show.html.erb` | Sections profil | Wrapper `_card_section` |
| `profile/edit.html.erb` | Formulaire profil | Wrapper `_card_section` |
| `manager/time_entries/index.html.erb` | Tableau carte | Appliquer `_card_section` |
| `manager/time_entries/corrections.html.erb` | Liste corrections | Utiliser `_card_section` |
| `manager/work_schedules/index.html.erb` | Grille plannings | Standardiser |
| `manager/work_schedules/new.html.erb` | Formulaire | Wrapper |
| `manager/work_schedules/edit.html.erb` | Formulaire | Wrapper |
| `manager/team_schedules/index.html.erb` | Vue équipe | Cartes multiples |
| `manager/weekly_schedule_plans/index.html.erb` | Grille hebdo | Standardiser |
| `manager/weekly_schedule_plans/new.html.erb` | Formulaire | Wrapper |
| `manager/weekly_schedule_plans/edit.html.erb` | Formulaire | Wrapper |
| `notifications/index.html.erb` | Liste notifs | Appliquer `_card_section` |
| `notifications/_dropdown.html.erb` | Dropdown | Potentiellement `_card_section` |

#### Exemple de Refactorisation

**Avant** (`time_entries/index.html.erb`):
```erb
<div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
  <div class="flex items-center justify-between mb-4">
    <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
      Historique des Pointages
    </h2>
    <%= link_to "Exporter", export_time_entries_path,
        class: "text-sm text-indigo-600 hover:text-indigo-800" %>
  </div>

  <table class="...">
    <!-- contenu -->
  </table>
</div>
```

**Après**:
```erb
<%= render 'shared/card_section',
    title: 'Historique des Pointages',
    action_text: 'Exporter',
    action_path: export_time_entries_path do %>
  <table class="...">
    <!-- contenu -->
  </table>
<% end %>
```

**Gain par vue**: ~10-15 lignes éliminées

---

## Backend - Opportunités de Refactorisation

### Critique (À faire en priorité)

#### 1. Ajouter Tests Automatisés
**Priorité**: CRITIQUE
**Effort**: Large (10-15h)
**Risque**: Safe (aucune modification du code existant)

**Problème**: Aucun test configuré → Risque élevé de régression

**Action**:
```bash
# 1. Ajouter RSpec
bundle add rspec-rails factory_bot_rails faker --group test
rails generate rspec:install

# 2. Ajouter shoulda-matchers pour validations
bundle add shoulda-matchers --group test

# 3. Créer factories critiques
# spec/factories/employees.rb
# spec/factories/leave_requests.rb
# spec/factories/time_entries.rb
```

**Tests Prioritaires**:
1. `LeavePolicyEngine` (logique métier française critique)
2. `LeaveRequest` validations et callbacks
3. `TimeEntry` calculs et validations
4. `RttAccrualJob` calculs RTT

**Bénéfice**: Confiance pour refactoriser sans casser

---

#### 2. Fixer N+1 Queries Dashboard
**Priorité**: CRITIQUE
**Effort**: Small (1-2h)
**Risque**: Safe

**Fichier**: `app/controllers/dashboard_controller.rb:8-10`

**Problème Actuel**:
```ruby
def index
  @current_time_entry = current_employee.time_entries.where(clock_out: nil).first
  @leave_balances = current_employee.leave_balances
  @pending_requests = current_employee.leave_requests.pending.order(created_at: :desc).limit(5)

  # N+1 ici si on affiche les managers ou approved_by
end
```

**Solution**:
```ruby
def index
  @current_time_entry = current_employee.time_entries.where(clock_out: nil).first
  @leave_balances = current_employee.leave_balances.order(:leave_type)
  @pending_requests = current_employee.leave_requests
                                      .includes(:approved_by)
                                      .pending
                                      .order(created_at: :desc)
                                      .limit(5)
end
```

**Fichiers Concernés**:
- `dashboard_controller.rb`
- `leave_requests_controller.rb` (index action)
- `manager/leave_requests_controller.rb` (pending_approvals)

---

#### 3. Ajouter Index Base de Données
**Priorité**: CRITIQUE (Performance)
**Effort**: Small (30min)
**Risque**: Safe

**Action**:
```bash
rails generate migration AddPerformanceIndexes
```

**Migration**:
```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # LeaveRequest - utilisé dans scopes et queries fréquentes
    add_index :leave_requests, [:employee_id, :status]
    add_index :leave_requests, [:start_date, :end_date]
    add_index :leave_requests, :status

    # TimeEntry - filtres date et employee
    add_index :time_entries, [:employee_id, :clock_in]
    add_index :time_entries, :clock_in

    # Notifications
    add_index :notifications, [:recipient_id, :read_at]
    add_index :notifications, [:recipient_id, :created_at]
  end
end
```

**Bénéfice**: Requêtes dashboard/calendar 3-5x plus rapides

---

### Haute Priorité

#### 4. Extraire Service Objects - LeaveRequest Creation
**Priorité**: HIGH
**Effort**: Medium (3-4h)
**Risque**: Moderate

**Problème**: Controller `leave_requests_controller.rb#create` = 77 lignes (trop complexe)

**Fichier Actuel**: `app/controllers/leave_requests_controller.rb:14-91`

**Solution**: Créer `LeaveRequestCreator` service

**Nouveau Fichier**: `app/domains/leave_management/services/leave_request_creator.rb`
```ruby
module LeaveManagement
  module Services
    class LeaveRequestCreator
      attr_reader :employee, :params, :errors

      def initialize(employee, params)
        @employee = employee
        @params = params
        @errors = []
      end

      def call
        validate_params
        return failure if errors.any?

        leave_request = build_leave_request
        return failure(leave_request.errors.full_messages) unless leave_request.save

        handle_auto_approval(leave_request)
        send_notifications(leave_request)

        success(leave_request)
      end

      private

      def validate_params
        errors << "Dates invalides" if end_date_before_start_date?
        errors << "Type de congé invalide" unless valid_leave_type?
      end

      def build_leave_request
        employee.leave_requests.new(
          leave_type: params[:leave_type],
          start_date: params[:start_date],
          end_date: params[:end_date],
          days_count: calculate_days_count,
          status: 'pending'
        )
      end

      def handle_auto_approval(leave_request)
        return unless auto_approvable?(leave_request)
        leave_request.auto_approve!
      end

      def auto_approvable?(leave_request)
        leave_request.days_count <= 2 &&
          !leave_request.conflicts_with_team? &&
          sufficient_notice?(leave_request)
      end

      def send_notifications(leave_request)
        return unless leave_request.pending?
        LeaveRequestMailer.notify_manager(leave_request).deliver_later
      end

      def calculate_days_count
        policy_engine.calculate_working_days(
          Date.parse(params[:start_date]),
          Date.parse(params[:end_date])
        )
      end

      def policy_engine
        @policy_engine ||= LeavePolicyEngine.new(employee)
      end

      def success(leave_request)
        OpenStruct.new(success?: true, leave_request: leave_request)
      end

      def failure(error_messages = errors)
        OpenStruct.new(success?: false, errors: error_messages)
      end
    end
  end
end
```

**Controller Simplifié**:
```ruby
def create
  result = LeaveManagement::Services::LeaveRequestCreator.new(
    current_employee,
    leave_request_params
  ).call

  if result.success?
    redirect_to leave_requests_path,
                notice: "Demande de congé créée avec succès"
  else
    flash.now[:alert] = result.errors.join(', ')
    render :new, status: :unprocessable_entity
  end
end
```

**Bénéfice**: Controller passe de 77 lignes → 12 lignes, logique testable isolée

---

#### 5. Extraire Controller Concerns
**Priorité**: HIGH
**Effort**: Medium (2-3h)
**Risque**: Safe

**A. ManagerAuthorization Concern**

**Problème**: Code dupliqué dans 7 controllers manager

**Nouveau Fichier**: `app/controllers/concerns/manager_authorization.rb`
```ruby
module ManagerAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_manager_role
    helper_method :current_manager
  end

  private

  def ensure_manager_role
    unless current_employee.manager? || current_employee.hr? || current_employee.admin?
      redirect_to dashboard_path, alert: "Accès réservé aux managers"
    end
  end

  def current_manager
    @current_manager ||= current_employee if current_employee.manager_or_above?
  end

  def team_members
    @team_members ||= current_manager.team_members
  end
end
```

**Utilisation**:
```ruby
class Manager::TimeEntriesController < ApplicationController
  include ManagerAuthorization  # Au lieu de dupliquer before_action

  def index
    @time_entries = team_members.flat_map(&:time_entries)
                                 .sort_by(&:clock_in)
                                 .reverse
  end
end
```

**Fichiers Impactés** (7):
- `manager/time_entries_controller.rb`
- `manager/leave_requests_controller.rb`
- `manager/work_schedules_controller.rb`
- `manager/weekly_schedule_plans_controller.rb`
- `manager/team_schedules_controller.rb`

**B. ApiErrorHandling Concern**

**Nouveau Fichier**: `app/controllers/concerns/api_error_handling.rb`
```ruby
module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from Pundit::NotAuthorizedError, with: :forbidden
  end

  private

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: {
      error: "Validation failed",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def forbidden
    render json: { error: "Access denied" }, status: :forbidden
  end
end
```

**Utilisation**:
```ruby
class Api::V1::BaseController < ActionController::API
  include ApiErrorHandling  # Simplifie la gestion d'erreurs

  before_action :authenticate_employee!
end
```

---

#### 6. Splitter LeavePolicyEngine (God Object)
**Priorité**: HIGH
**Effort**: Large (6-8h)
**Risque**: Moderate (tests critiques requis)

**Problème**: `leave_policy_engine.rb` = 308 lignes, 4 responsabilités distinctes

**Structure Actuelle**: 1 fichier monolithique
**Structure Proposée**: 4 services séparés

**A. FrenchPublicHolidaysService**
```ruby
# app/domains/leave_management/services/french_public_holidays_service.rb
module LeaveManagement
  module Services
    class FrenchPublicHolidaysService
      FIXED_HOLIDAYS = {
        [1, 1]   => "Jour de l'an",
        [5, 1]   => "Fête du Travail",
        [5, 8]   => "Victoire 1945",
        [7, 14]  => "Fête Nationale",
        [8, 15]  => "Assomption",
        [11, 1]  => "Toussaint",
        [11, 11] => "Armistice 1918",
        [12, 25] => "Noël"
      }.freeze

      def self.for_year(year)
        holidays = fixed_holidays_for_year(year)
        holidays << easter_monday(year)
        holidays << ascension(year)
        holidays << whit_monday(year)
        holidays.sort
      end

      def self.is_holiday?(date)
        for_year(date.year).include?(date)
      end

      private

      def self.fixed_holidays_for_year(year)
        FIXED_HOLIDAYS.keys.map { |month, day| Date.new(year, month, day) }
      end

      def self.easter_monday(year)
        # Algorithme de Meeus/Jones/Butcher
        a = year % 19
        b = year / 100
        c = year % 100
        d = b / 4
        e = b % 4
        f = (b + 8) / 25
        g = (b - f + 1) / 3
        h = (19 * a + b - d - g + 15) % 30
        i = c / 4
        k = c % 4
        l = (32 + 2 * e + 2 * i - h - k) % 7
        m = (a + 11 * h + 22 * l) / 451
        month = (h + l - 7 * m + 114) / 31
        day = ((h + l - 7 * m + 114) % 31) + 1

        Date.new(year, month, day) + 1.day  # Lundi de Pâques
      end

      def self.ascension(year)
        easter_monday(year) + 38.days
      end

      def self.whit_monday(year)
        easter_monday(year) + 49.days
      end
    end
  end
end
```

**B. WorkingDaysCalculator**
```ruby
# app/domains/leave_management/services/working_days_calculator.rb
module LeaveManagement
  module Services
    class WorkingDaysCalculator
      def initialize(start_date, end_date, work_schedule = nil)
        @start_date = start_date
        @end_date = end_date
        @work_schedule = work_schedule
      end

      def call
        return 0 if @start_date > @end_date

        (@start_date..@end_date).count do |date|
          working_day?(date)
        end
      end

      private

      def working_day?(date)
        return false if weekend?(date)
        return false if FrenchPublicHolidaysService.is_holiday?(date)
        return false if non_working_day_for_schedule?(date)
        true
      end

      def weekend?(date)
        date.saturday? || date.sunday?
      end

      def non_working_day_for_schedule?(date)
        return false unless @work_schedule
        !@work_schedule.works_on?(date.strftime('%A').downcase)
      end
    end
  end
end
```

**C. CpAccrualCalculator**
```ruby
# app/domains/leave_management/services/cp_accrual_calculator.rb
module LeaveManagement
  module Services
    class CpAccrualCalculator
      CP_ACCRUAL_PER_MONTH = 2.5
      MAX_CP_PER_YEAR = 30.0

      def initialize(employee)
        @employee = employee
      end

      def calculate_monthly_accrual
        return 0 unless eligible_for_accrual?

        [CP_ACCRUAL_PER_MONTH, remaining_accrual_capacity].min
      end

      def calculate_for_period(start_date, end_date)
        months = months_between(start_date, end_date)
        [months * CP_ACCRUAL_PER_MONTH, MAX_CP_PER_YEAR].min
      end

      private

      def eligible_for_accrual?
        @employee.active? && !@employee.on_unpaid_leave?
      end

      def remaining_accrual_capacity
        current_balance = @employee.leave_balances.find_by(leave_type: 'cp')&.balance || 0
        MAX_CP_PER_YEAR - current_balance
      end

      def months_between(start_date, end_date)
        ((end_date.year - start_date.year) * 12 +
         (end_date.month - start_date.month)).clamp(0, 12)
      end
    end
  end
end
```

**D. RttAccrualCalculator**
```ruby
# app/domains/leave_management/services/rtt_accrual_calculator.rb
module LeaveManagement
  module Services
    class RttAccrualCalculator
      LEGAL_WEEKLY_HOURS = 35.0
      HOURS_PER_RTT_DAY = 7.0  # Moyenne journée travail

      def initialize(employee)
        @employee = employee
      end

      def calculate_from_time_entry(time_entry)
        return 0 unless eligible_for_rtt?

        weekly_hours = calculate_weekly_hours(time_entry.clock_in)
        overtime_hours = [weekly_hours - LEGAL_WEEKLY_HOURS, 0].max

        overtime_hours / HOURS_PER_RTT_DAY
      end

      def calculate_monthly_accrual
        # Pour calcul batch mensuel
        time_entries = @employee.time_entries
                                .where('clock_in >= ?', 1.month.ago)

        total_overtime = time_entries.sum do |entry|
          next 0 unless entry.duration
          weekly_hours = calculate_weekly_hours(entry.clock_in)
          [weekly_hours - LEGAL_WEEKLY_HOURS, 0].max
        end

        total_overtime / HOURS_PER_RTT_DAY
      end

      private

      def eligible_for_rtt?
        @employee.work_schedule&.eligible_for_rtt?
      end

      def calculate_weekly_hours(date)
        week_start = date.beginning_of_week
        week_end = date.end_of_week

        @employee.time_entries
                 .where(clock_in: week_start..week_end)
                 .where.not(duration: nil)
                 .sum(:duration) / 3600.0  # Convertir secondes en heures
      end
    end
  end
end
```

**LeavePolicyEngine Simplifié** (devient orchestrateur):
```ruby
module LeaveManagement
  module Services
    class LeavePolicyEngine
      delegate :for_year, :is_holiday?, to: :holidays_service, prefix: :holiday

      def initialize(employee)
        @employee = employee
      end

      def calculate_working_days(start_date, end_date)
        WorkingDaysCalculator.new(
          start_date,
          end_date,
          @employee.work_schedule
        ).call
      end

      def calculate_cp_accrual
        CpAccrualCalculator.new(@employee).calculate_monthly_accrual
      end

      def calculate_rtt_accrual_from_time_entry(time_entry)
        RttAccrualCalculator.new(@employee).calculate_from_time_entry(time_entry)
      end

      def french_holidays(year)
        FrenchPublicHolidaysService.for_year(year)
      end

      private

      def holidays_service
        FrenchPublicHolidaysService
      end
    end
  end
end
```

**Bénéfice**: 308 lignes → 4 services cohérents de ~70 lignes chacun, testables isolément

---

#### 7. Créer API Serializers
**Priorité**: HIGH
**Effort**: Medium (3-4h)
**Risque**: Safe

**Problème**: Controllers API retournent objets ActiveRecord directement → sur-exposition données

**Solution**: Utiliser `active_model_serializers` ou créer serializers manuels

**Installation**:
```bash
bundle add active_model_serializers
```

**Exemple**: `app/serializers/leave_request_serializer.rb`
```ruby
class LeaveRequestSerializer < ActiveModel::Serializer
  attributes :id, :leave_type, :start_date, :end_date, :days_count,
             :status, :approved_at, :rejection_reason, :created_at

  belongs_to :employee, serializer: EmployeeSerializer
  belongs_to :approved_by, serializer: EmployeeSerializer, if: :approved?

  def approved?
    object.approved?
  end
end
```

**Exemple**: `app/serializers/employee_serializer.rb`
```ruby
class EmployeeSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :email, :role

  # NE PAS exposer: password_digest, reset_password_token, etc.
end
```

**Utilisation dans Controller**:
```ruby
class Api::V1::LeaveRequestsController < Api::V1::BaseController
  def index
    leave_requests = current_employee.leave_requests.includes(:approved_by)
    render json: leave_requests, each_serializer: LeaveRequestSerializer
  end

  def show
    leave_request = current_employee.leave_requests.find(params[:id])
    render json: leave_request, serializer: LeaveRequestSerializer
  end
end
```

**Serializers à Créer**:
- `EmployeeSerializer`
- `LeaveRequestSerializer`
- `LeaveBalanceSerializer`
- `TimeEntrySerializer`
- `WorkScheduleSerializer`
- `NotificationSerializer`

---

### Moyenne Priorité

#### 8. Extraire Validation Concerns (Models)
**Priorité**: MEDIUM
**Effort**: Small (2h)
**Risque**: Safe

**A. SameTenantValidation Concern**

**Problème**: Code dupliqué dans `LeaveRequest`, `TimeEntry`, etc.

**Nouveau Fichier**: `app/models/concerns/same_tenant_validation.rb`
```ruby
module SameTenantValidation
  extend ActiveSupport::Concern

  class_methods do
    def validates_same_tenant(*associations)
      associations.each do |association|
        validate :"validate_#{association}_same_tenant"

        define_method :"validate_#{association}_same_tenant" do
          record = send(association)
          return unless record && organization_id

          if record.organization_id != organization_id
            errors.add(association, 'must belong to the same organization')
          end
        end
      end
    end
  end
end
```

**Utilisation**:
```ruby
class LeaveRequest < ApplicationRecord
  include SameTenantValidation

  validates_same_tenant :employee, :approved_by

  # Remplace:
  # validate :employee_belongs_to_same_organization
  # validate :approver_belongs_to_same_organization
end
```

**B. DateRangeValidation Concern**

**Nouveau Fichier**: `app/models/concerns/date_range_validation.rb`
```ruby
module DateRangeValidation
  extend ActiveSupport::Concern

  class_methods do
    def validates_date_range(start_attr, end_attr, message: 'must be after start date')
      validate do
        start_date = send(start_attr)
        end_date = send(end_attr)

        next if start_date.blank? || end_date.blank?

        if end_date < start_date
          errors.add(end_attr, message)
        end
      end
    end
  end
end
```

**Utilisation**:
```ruby
class LeaveRequest < ApplicationRecord
  include DateRangeValidation

  validates_date_range :start_date, :end_date

  # Remplace:
  # validate :end_date_after_start_date
end
```

---

#### 9. Refactoriser RttAccrualJob
**Priorité**: MEDIUM
**Effort**: Medium (3-4h)
**Risque**: Moderate

**Problème**: `rtt_accrual_job.rb` = 137 lignes, trop complexe

**Fichier**: `app/jobs/rtt_accrual_job.rb`

**Solution**: Utiliser `RttAccrualCalculator` service (créé précédemment)

**Job Simplifié**:
```ruby
class RttAccrualJob < ApplicationJob
  queue_as :default

  def perform(period: :weekly)
    ActsAsTenant.without_tenant do
      Organization.find_each do |organization|
        ActsAsTenant.with_tenant(organization) do
          process_organization_employees(period)
        end
      end
    end
  end

  private

  def process_organization_employees(period)
    eligible_employees.find_each do |employee|
      calculator = LeaveManagement::Services::RttAccrualCalculator.new(employee)
      rtt_days = calculator.calculate_monthly_accrual

      next if rtt_days.zero?

      update_rtt_balance(employee, rtt_days)
    end
  end

  def eligible_employees
    Employee.active
            .joins(:work_schedule)
            .where(work_schedules: { eligible_for_rtt: true })
  end

  def update_rtt_balance(employee, days)
    balance = employee.leave_balances.find_or_create_by(leave_type: 'rtt')
    balance.increment!(:balance, days)

    Rails.logger.info "RTT accrued for #{employee.email}: +#{days} days"
  rescue => e
    Rails.logger.error "RTT accrual failed for #{employee.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
```

**Bénéfice**: 137 lignes → 40 lignes, logique calcul déléguée au service

---

#### 10. Optimiser Policies (N+1)
**Priorité**: MEDIUM
**Effort**: Small (1-2h)
**Risque**: Safe

**Fichiers**:
- `app/policies/leave_request_policy.rb`
- `app/policies/time_entry_policy.rb`

**Problème**: Méthodes helper causent N+1 queries

**Exemple Actuel** (`leave_request_policy.rb`):
```ruby
def approve?
  user.manager? && manages?(record.employee)
end

private

def manages?(employee)
  user.team_members.include?(employee)  # N+1 ici !
end
```

**Solution**: Utiliser IDs au lieu d'objets
```ruby
def approve?
  user.manager? && manages?(record.employee_id)
end

private

def manages?(employee_id)
  team_member_ids.include?(employee_id)
end

def team_member_ids
  @team_member_ids ||= user.team_members.pluck(:id)
end
```

**Ou encore mieux - Query directe**:
```ruby
def approve?
  user.manager? && user.team_members.exists?(record.employee_id)
end
```

---

#### 11. Créer NotificationService
**Priorité**: MEDIUM
**Effort**: Medium (2-3h)
**Risque**: Safe

**Problème**: Logique notification dispersée dans controllers et models

**Nouveau Fichier**: `app/services/notification_service.rb`
```ruby
class NotificationService
  def self.leave_request_created(leave_request)
    return unless leave_request.employee.manager

    Notification.create!(
      recipient: leave_request.employee.manager,
      notification_type: 'leave_request_pending',
      notifiable: leave_request,
      title: "Nouvelle demande de congé",
      message: "#{leave_request.employee.full_name} a demandé #{leave_request.days_count} jour(s) de #{leave_request.leave_type}",
      action_url: Rails.application.routes.url_helpers.pending_approvals_leave_requests_path
    )

    # Email asynchrone
    LeaveRequestMailer.notify_manager(leave_request).deliver_later
  end

  def self.leave_request_approved(leave_request)
    Notification.create!(
      recipient: leave_request.employee,
      notification_type: 'leave_request_approved',
      notifiable: leave_request,
      title: "Congé approuvé",
      message: "Votre demande de #{leave_request.days_count} jour(s) a été approuvée",
      action_url: Rails.application.routes.url_helpers.leave_request_path(leave_request)
    )

    LeaveRequestMailer.notify_approval(leave_request).deliver_later
  end

  def self.leave_request_rejected(leave_request)
    Notification.create!(
      recipient: leave_request.employee,
      notification_type: 'leave_request_rejected',
      notifiable: leave_request,
      title: "Congé refusé",
      message: "Votre demande de #{leave_request.days_count} jour(s) a été refusée",
      action_url: Rails.application.routes.url_helpers.leave_request_path(leave_request)
    )

    LeaveRequestMailer.notify_rejection(leave_request).deliver_later
  end

  def self.time_entry_correction_requested(time_entry, manager)
    Notification.create!(
      recipient: time_entry.employee,
      notification_type: 'time_entry_correction',
      notifiable: time_entry,
      title: "Correction demandée",
      message: "#{manager.full_name} a demandé une correction sur votre pointage",
      action_url: Rails.application.routes.url_helpers.time_entries_path
    )

    TimeEntryMailer.correction_requested(time_entry, manager).deliver_later
  end
end
```

**Utilisation**:
```ruby
# Dans LeaveRequestCreator service
def send_notifications(leave_request)
  NotificationService.leave_request_created(leave_request)
end

# Dans LeaveRequestsController
def approve
  @leave_request.approve!(current_employee)
  NotificationService.leave_request_approved(@leave_request)
  redirect_to pending_approvals_leave_requests_path, notice: "Demande approuvée"
end
```

---

### Basse Priorité

#### 12. Créer Value Objects
**Priorité**: LOW
**Effort**: Medium (3-4h)
**Risque**: Safe

**A. DateRange Value Object**

**Nouveau Fichier**: `app/models/date_range.rb`
```ruby
class DateRange
  include Comparable

  attr_reader :start_date, :end_date

  def initialize(start_date, end_date)
    @start_date = start_date.to_date
    @end_date = end_date.to_date

    raise ArgumentError, "End date must be after start date" if @end_date < @start_date
  end

  def duration_in_days
    (@end_date - @start_date).to_i + 1
  end

  def overlaps?(other)
    @start_date <= other.end_date && @end_date >= other.start_date
  end

  def contains?(date)
    date = date.to_date
    date >= @start_date && date <= @end_date
  end

  def to_range
    @start_date..@end_date
  end

  def working_days(work_schedule = nil)
    LeaveManagement::Services::WorkingDaysCalculator.new(
      @start_date,
      @end_date,
      work_schedule
    ).call
  end

  def <=>(other)
    [@start_date, @end_date] <=> [other.start_date, other.end_date]
  end
end
```

**Utilisation**:
```ruby
# Dans LeaveRequest
def date_range
  @date_range ||= DateRange.new(start_date, end_date)
end

def conflicts_with?(other_request)
  date_range.overlaps?(other_request.date_range)
end

# Dans controller
date_range = DateRange.new(params[:start_date], params[:end_date])
working_days = date_range.working_days(employee.work_schedule)
```

**B. LeaveType Value Object**

**Nouveau Fichier**: `app/models/leave_type.rb`
```ruby
class LeaveType
  TYPES = {
    cp: {
      name_fr: 'Congés Payés',
      accrual_rate: 2.5,
      max_per_year: 30,
      requires_approval: true,
      paid: true
    },
    rtt: {
      name_fr: 'RTT',
      accrual_rate: :variable,
      requires_approval: true,
      paid: true
    },
    maladie: {
      name_fr: 'Maladie',
      requires_approval: false,
      requires_certificate: true,
      paid: true
    },
    sans_solde: {
      name_fr: 'Congé Sans Solde',
      requires_approval: true,
      paid: false
    }
  }.freeze

  attr_reader :code

  def initialize(code)
    @code = code.to_sym
    raise ArgumentError, "Invalid leave type: #{code}" unless TYPES.key?(@code)
  end

  def name_fr
    TYPES[@code][:name_fr]
  end

  def requires_approval?
    TYPES[@code][:requires_approval]
  end

  def paid?
    TYPES[@code][:paid]
  end

  def ==(other)
    other.is_a?(LeaveType) && @code == other.code
  end

  def to_s
    @code.to_s
  end
end
```

---

#### 13. Améliorer Helpers
**Priorité**: LOW
**Effort**: Small (1h)
**Risque**: Safe

**Problème**: `time_entries_helper.rb` a méthodes trop complexes

**Fichier**: `app/helpers/time_entries_helper.rb`

**Refactorisation**:
```ruby
module TimeEntriesHelper
  def format_duration(seconds)
    return "En cours..." if seconds.nil?

    Duration.new(seconds).to_human
  end

  def status_badge_class(time_entry)
    TimeEntryStatusPresenter.new(time_entry).badge_class
  end

  def time_entry_row_class(time_entry)
    if time_entry.flagged_for_review?
      'bg-yellow-50 dark:bg-yellow-900/20'
    elsif time_entry.duration && time_entry.duration > 10.hours
      'bg-red-50 dark:bg-red-900/20'
    else
      ''
    end
  end
end

# Nouveau fichier: app/presenters/time_entry_status_presenter.rb
class TimeEntryStatusPresenter
  def initialize(time_entry)
    @time_entry = time_entry
  end

  def badge_class
    case status
    when :in_progress
      'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    when :completed
      'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
    when :flagged
      'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
    when :overtime
      'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200'
    end
  end

  private

  def status
    return :in_progress unless @time_entry.clock_out
    return :flagged if @time_entry.flagged_for_review?
    return :overtime if @time_entry.duration > 10.hours
    :completed
  end
end

# Nouveau fichier: app/models/duration.rb
class Duration
  def initialize(seconds)
    @seconds = seconds
  end

  def to_human
    hours = @seconds / 3600
    minutes = (@seconds % 3600) / 60
    "#{hours}h #{minutes.to_s.rjust(2, '0')}m"
  end

  def hours
    @seconds / 3600.0
  end

  def days(hours_per_day = 7)
    hours / hours_per_day
  end
end
```

---

## Roadmap d'Implémentation

### Sprint 1: Fondations (Tests & Performance)
**Durée Estimée**: 2-3 jours
**Risque**: LOW - Aucune modification logique métier

1. ✅ **Setup RSpec** (2-3h)
   - Installer gems
   - Configurer `spec/rails_helper.rb`
   - Créer factories de base

2. ✅ **Tests Critiques** (6-8h)
   - `LeavePolicyEngine` (calculs CP/RTT, jours fériés)
   - `LeaveRequest` (validations, workflows)
   - `TimeEntry` (durée, validations 10h max)

3. ✅ **Ajouter Index DB** (30min)
   - Migration index performance
   - Tester impact avec `EXPLAIN ANALYZE`

4. ✅ **Fixer N+1 Dashboard** (1-2h)
   - Ajouter `.includes()` dans controllers
   - Vérifier avec `bullet` gem

**Validation**: Tous les tests passent, dashboard 3x plus rapide

---

### Sprint 2: Service Objects & Concerns
**Durée Estimée**: 3-4 jours
**Risque**: MEDIUM - Modifications structure code

5. ✅ **Extraire Service Objects** (6-8h)
   - `LeaveRequestCreator`
   - `NotificationService`
   - Tests unitaires pour chaque service

6. ✅ **Controller Concerns** (2-3h)
   - `ManagerAuthorization`
   - `ApiErrorHandling`
   - Appliquer dans controllers existants

7. ✅ **Model Concerns** (2h)
   - `SameTenantValidation`
   - `DateRangeValidation`
   - Simplifier models

**Validation**: Controllers < 50 lignes, tests passent

---

### Sprint 3: Splitter God Objects
**Durée Estimée**: 4-5 jours
**Risque**: HIGH - Logique métier critique

8. ✅ **Splitter LeavePolicyEngine** (6-8h)
   - Créer 4 services séparés
   - Migrer tests existants
   - Tester exhaustivement calculs français

9. ✅ **Refactoriser RttAccrualJob** (3-4h)
   - Utiliser `RttAccrualCalculator`
   - Simplifier job à 40 lignes
   - Tests job avec mocks

**Validation**: Job batch fonctionne, calculs RTT corrects

---

### Sprint 4: API & Polish
**Durée Estimée**: 3-4 jours
**Risque**: LOW

10. ✅ **API Serializers** (3-4h)
    - Créer 6 serializers
    - Appliquer dans API controllers
    - Vérifier pas de sur-exposition données

11. ✅ **Optimiser Policies** (1-2h)
    - Fixer N+1 avec `.pluck(:id)`
    - Tests performance

12. ✅ **Value Objects** (3-4h) - OPTIONNEL
    - `DateRange`
    - `LeaveType`
    - Intégrer progressivement

**Validation**: API propre, pas de N+1

---

### Sprint 5: Frontend Polish
**Durée Estimée**: 1-2 jours
**Risque**: LOW

13. ✅ **Appliquer Card Partials** (4-6h)
    - Refactoriser 19 vues
    - Tests visuels manuels
    - Vérifier responsive mobile/desktop

**Validation**: UI cohérente, ~200 lignes éliminées

---

## Métriques de Succès

### Avant Refactorisation
- **Couverture Tests**: 0%
- **Lignes Dupliquées**: ~500 lignes (frontend + backend)
- **Complexité Cyclomatique**: LeavePolicyEngine = 45, LeaveRequestsController#create = 18
- **N+1 Queries**: 12 pages affectées
- **Temps Dashboard**: ~450ms (avec 5 leave requests)

### Après Refactorisation (Objectifs)
- **Couverture Tests**: 80%+ (models + services critiques)
- **Lignes Dupliquées**: <100 lignes
- **Complexité Cyclomatique**: Tous fichiers < 10
- **N+1 Queries**: 0 pages affectées
- **Temps Dashboard**: <150ms (3x plus rapide)
- **Maintenabilité**: Tous services < 100 lignes

---

## Notes de Sécurité

### Points de Vigilance

1. **Multi-Tenancy**: TOUJOURS vérifier `acts_as_tenant` actif
   - Utiliser `ActsAsTenant.with_tenant(org)` dans jobs
   - Tests doivent créer organizations séparées

2. **API Authentication**: JWT/Token non implémenté
   - Ne PAS exposer API en production sans auth
   - Implémenter `devise-jwt` ou `doorkeeper`

3. **Mass Assignment**: Utiliser strong params partout
   - Vérifier `leave_request_params` ne permet pas `:status, :approved_by_id`
   - Idem pour `time_entry_params`

4. **SQL Injection**: JAMAIS interpoler params dans queries
   - Toujours utiliser placeholders: `where("date > ?", params[:date])`
   - Éviter `.order(params[:sort])` sans whitelist

5. **Sensitive Data Logging**: Filtrer logs production
   - Ajouter dans `config/initializers/filter_parameter_logging.rb`:
   ```ruby
   Rails.application.config.filter_parameters += [
     :password, :password_confirmation, :reset_password_token,
     :authentication_token, :otp_secret
   ]
   ```

---

## Annexe: Commandes Utiles

### Détecter N+1 Queries
```bash
# Ajouter bullet gem
bundle add bullet --group development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
end
```

### Analyser Performance DB
```bash
# Console Rails
rails c

# Activer logging SQL
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Tester query avec EXPLAIN
Employee.joins(:leave_requests).where(leave_requests: { status: 'pending' }).explain
```

### Mesurer Complexité Code
```bash
# Installer flog
gem install flog

# Analyser fichier
flog app/domains/leave_management/services/leave_policy_engine.rb

# Analyser dossier
flog app/domains/leave_management/
```

### Trouver Code Dupliqué
```bash
# Installer flay
gem install flay

# Analyser duplication
flay app/controllers/manager/
```

---

**Dernière Mise à Jour**: 2026-01-13
**Auteur**: Claude Code (analyse automatisée)
**Statut**: Prêt pour implémentation Sprint 1
