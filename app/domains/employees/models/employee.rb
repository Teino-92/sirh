# frozen_string_literal: true

class Employee < ApplicationRecord
  # Multi-tenancy: scope all queries to current organization
  acts_as_tenant :organization

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  belongs_to :organization
  belongs_to :manager, class_name: 'Employee', optional: true
  has_many :direct_reports, class_name: 'Employee', foreign_key: :manager_id, dependent: :nullify

  # Avatar
  has_one_attached :avatar

  has_many :leave_balances, dependent: :destroy
  has_many :leave_requests, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_one :work_schedule, dependent: :destroy
  has_many :weekly_schedule_plans, dependent: :destroy
  has_many :notifications, dependent: :destroy

  # Leave requests approved by this employee (when they are a manager)
  has_many :approved_leave_requests, class_name: 'LeaveRequest', foreign_key: :approved_by_id

  # Performance Layer relationships
  has_many :owned_objectives, class_name: 'Objective', as: :owner, dependent: :destroy
  has_many :managed_objectives, class_name: 'Objective', foreign_key: :manager_id, dependent: :nullify
  has_many :managed_one_on_ones, class_name: 'OneOnOne', foreign_key: :manager_id, dependent: :nullify
  has_many :employee_one_on_ones, class_name: 'OneOnOne', foreign_key: :employee_id, dependent: :destroy
  has_many :action_items, foreign_key: :responsible_id, dependent: :nullify

  # Evaluations relationships
  has_many :evaluations, foreign_key: :employee_id, dependent: :destroy
  has_many :managed_evaluations, class_name: 'Evaluation', foreign_key: :manager_id, dependent: :nullify

  # Onboarding relationships
  has_many :onboardings,         foreign_key: :employee_id, dependent: :destroy
  has_many :managed_onboardings, class_name: 'Onboarding', foreign_key: :manager_id, dependent: :nullify

  # Training relationships
  has_many :training_assignments, class_name: 'TrainingAssignment', dependent: :destroy
  has_many :trainings, class_name: 'Training', through: :training_assignments
  has_many :assigned_trainings, class_name: 'TrainingAssignment', foreign_key: :assigned_by_id, dependent: :nullify

  validates :first_name, :last_name, :contract_type, :start_date, presence: true
  ROLES = %w[employee manager hr admin].freeze

  validates :role, presence: true, inclusion: { in: ROLES }

  # French contract types
  validates :contract_type, inclusion: { in: %w[CDI CDD Stage Alternance Interim] }

  scope :active, -> { where("(settings->>'active') IS NULL OR (settings->>'active') = 'true'") }
  scope :managers, -> { where(role: %w[manager hr admin]) }
  scope :by_department, ->(dept) { where(department: dept) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def manager?
    %w[manager hr admin].include?(role)
  end

  def hr_or_admin?
    %w[hr admin].include?(role)
  end

  def admin?
    role == 'admin'
  end

  def hr?
    role == 'hr'
  end

  def active?
    settings.fetch('active', true)
  end

  # "Cadre" employees have a fixed salary — no clocking in/out and no work schedule.
  # This is independent of role: a manager can be non-cadre and a plain employee can be cadre.
  def cadre?
    settings.fetch('cadre', false)
  end

  DASHBOARD_CARD_PERMISSIONS = {
    'clock_inout'          => ->(e) { !e.cadre? },
    'today_schedule'       => ->(e) { !e.cadre? },
    'team_planning'        => ->(e) { e.manager? },
    'personal_planning'    => ->(e) { !e.manager? },
    'pending_approvals'    => ->(e) { e.manager? },
    'team_performance'     => ->(e) { e.manager? },
    'upcoming_one_on_ones' => ->(e) { e.manager? },
    'absences_today'       => ->(e) { e.hr_or_admin? },
    'active_onboardings'   => ->(e) { e.hr_or_admin? },
    'leave_balances'       => ->(_e) { true },
    'upcoming_leaves'      => ->(_e) { true },
    'my_performance'       => ->(_e) { true },
    'pending_requests'     => ->(_e) { true },
    'quick_links'          => ->(_e) { true }
  }.freeze

  DASHBOARD_DEFAULT_LAYOUTS = {
    'employee' => {
      'order'  => %w[leave_balances personal_planning upcoming_leaves pending_requests my_performance quick_links],
      'hidden' => [],
      'sizes'  => { 'leave_balances' => 'normal', 'personal_planning' => 'normal',
                    'upcoming_leaves' => 'normal', 'pending_requests' => 'normal',
                    'my_performance' => 'normal', 'quick_links' => 'normal' }
    },
    'manager' => {
      'order'  => %w[pending_approvals team_planning leave_balances upcoming_one_on_ones team_performance my_performance pending_requests quick_links],
      'hidden' => [],
      'sizes'  => { 'pending_approvals' => 'normal', 'team_planning' => 'normal',
                    'leave_balances' => 'normal', 'upcoming_one_on_ones' => 'normal',
                    'team_performance' => 'normal', 'my_performance' => 'normal',
                    'pending_requests' => 'normal', 'quick_links' => 'normal' }
    },
    'hr' => {
      'order'  => %w[absences_today active_onboardings leave_balances pending_requests my_performance quick_links],
      'hidden' => [],
      'sizes'  => { 'absences_today' => 'normal', 'active_onboardings' => 'normal',
                    'leave_balances' => 'normal', 'pending_requests' => 'normal',
                    'my_performance' => 'normal', 'quick_links' => 'normal' }
    },
    'admin' => {
      'order'  => %w[absences_today active_onboardings leave_balances pending_requests my_performance quick_links],
      'hidden' => [],
      'sizes'  => { 'absences_today' => 'normal', 'active_onboardings' => 'normal',
                    'leave_balances' => 'normal', 'pending_requests' => 'normal',
                    'my_performance' => 'normal', 'quick_links' => 'normal' }
    }
  }.freeze

  def dashboard_layout
    stored = settings.fetch('dashboard_layout', nil)
    return default_dashboard_layout if stored.blank?
    default = default_dashboard_layout
    merged_sizes = default['sizes'].merge(stored['sizes'] || {})
    # Normalize removed 'compact' size to 'normal'
    merged_sizes.transform_values! { |v| v == 'compact' ? 'normal' : v }
    { 'order'  => stored['order'] || default['order'],
      'hidden' => stored['hidden'] || [],
      'sizes'  => merged_sizes }
  end

  def dashboard_layout=(layout_hash)
    self.settings = settings.merge('dashboard_layout' => layout_hash)
  end

  def dashboard_card_permitted?(card_id)
    DASHBOARD_CARD_PERMISSIONS.fetch(card_id, ->(_e) { true }).call(self)
  end

  def tenure_in_months
    ((Time.current.to_date - start_date) / 30).to_i
  end

  # Virtual euro-denominated attributes for form display/input.
  # The actual storage columns are *_cents (integers).
  # Using virtual attrs avoids Rails form builder overriding the value: option.
  attr_writer :gross_salary_eur, :variable_pay_eur

  def gross_salary_eur
    @gross_salary_eur || (gross_salary_cents / 100.0).to_s
  end

  def variable_pay_eur
    @variable_pay_eur || (variable_pay_cents / 100.0).to_s
  end

  # Salary helpers — all amounts in euros (converted from cents)
  def gross_salary
    gross_salary_cents / 100.0
  end

  def variable_pay
    variable_pay_cents / 100.0
  end

  # Total monthly cost for the employer: (gross + variable) × employer charges rate
  def total_employer_cost
    (gross_salary + variable_pay) * employer_charges_rate.to_f
  end

  # Team members this employee manages
  def team_members
    return Employee.none unless manager?

    organization.employees.where(manager_id: id)
  end

  private

  def default_dashboard_layout
    base = DASHBOARD_DEFAULT_LAYOUTS.fetch(role, DASHBOARD_DEFAULT_LAYOUTS['employee']).deep_dup
    base['order'].select! { |card| dashboard_card_permitted?(card) }
    base
  end
end
