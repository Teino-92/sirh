# frozen_string_literal: true

class Employee < ApplicationRecord
  # Multi-tenancy: scope all queries to current organization
  acts_as_tenant :organization

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :timeoutable,
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
  has_many :employee_onboardings,         class_name: 'EmployeeOnboarding', foreign_key: :employee_id, dependent: :destroy
  has_many :managed_employee_onboardings, class_name: 'EmployeeOnboarding', foreign_key: :manager_id, dependent: :nullify

  # Training relationships
  has_many :training_assignments, class_name: 'TrainingAssignment', dependent: :destroy
  has_many :trainings, class_name: 'Training', through: :training_assignments
  has_many :assigned_trainings, class_name: 'TrainingAssignment', foreign_key: :assigned_by_id, dependent: :nullify

  # Sensitive payroll fields — encrypted at rest via ActiveRecord Encryption
  encrypts :nir,  deterministic: false
  encrypts :iban, deterministic: false

  validates :first_name, :last_name, :contract_type, :start_date, presence: true
  ROLES = %w[employee manager hr admin].freeze

  validates :role, presence: true, inclusion: { in: ROLES }

  # French contract types
  validates :contract_type, inclusion: { in: %w[CDI CDD Stage Alternance Interim] }

  # Payroll validations
  validates :nir, format: { with: /\A[12][0-9]{12}\z/, message: "doit contenir 13 chiffres (commence par 1 ou 2)" },
                  allow_blank: true
  validate :nir_unique_within_organization, if: -> { nir.present? && nir_changed? }
  validates :part_time_rate, numericality: { greater_than: 0, message: "doit être supérieur à 0" }, allow_nil: true
  validates :part_time_rate, numericality: { less_than_or_equal_to: 1, message: "ne peut pas dépasser 1.0 (temps plein)" }, allow_nil: true
  # end_date is the CDD contract end date
  validates :end_date, presence: { message: "est obligatoire pour un CDD" }, if: -> { contract_type == 'CDD' }

  TERMINATION_REASONS = %w[resignation layoff_economic layoff_personal mutual_agreement
                            cdd_end trial_period_end retirement death].freeze
  validates :termination_reason,
            inclusion: { in: TERMINATION_REASONS, message: "n'est pas une valeur valide" },
            allow_blank: true

  # Format officiel INSEE : 01–95, 2A, 2B, 971–976
  validates :birth_department,
            format: { with: /\A(\d{2}|2[AB]|97[1-6])\z/, message: "format invalide (ex: 75, 2A, 971)" },
            allow_blank: true

  scope :active, -> { where("(settings->>'active') IS NULL OR (settings->>'active') = 'true'") }
  scope :managers, -> { where(role: %w[manager hr admin]) }
  scope :by_department, ->(dept) { where(department: dept) }
  scope :hr_officers, -> { where(role: 'hr') }
  scope :covering_department, ->(dept) { where(role: 'hr').where("hr_perimeter @> ARRAY[?]::text[]", dept) }

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

  # Returns the HR officer(s) covering this employee's department.
  # Returns nil if no department set or no HR officer covers it.
  def hr_referent
    return nil if department.blank?
    Employee.covering_department(department).first
  end

  # For HR officers: parsed perimeter as array, settable from a comma-separated string.
  def hr_perimeter_list
    (hr_perimeter || []).join(', ')
  end

  def hr_perimeter_list=(value)
    self.hr_perimeter = value.to_s.split(',').map(&:strip).reject(&:blank?)
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
    'absences_today'       => ->(e) { e.manager? },
    'active_onboardings'   => ->(e) { e.hr_or_admin? },
    'trial_period_alerts'  => ->(e) { e.manager? },
    'leave_balances'       => ->(_e) { true },
    'upcoming_leaves'      => ->(_e) { true },
    'my_performance'       => ->(_e) { true },
    'pending_requests'     => ->(_e) { true },
    'quick_links'          => ->(_e) { true },
    'hr_referent'          => ->(e) { e.department.present? && !e.hr? }
  }.freeze

  # GridStack layout: each card has x, y, w, h in grid units (12-column grid).
  # w: 1-12 columns, h: height units (~100px each). Cards snap to the grid on drag/resize.
  DASHBOARD_DEFAULT_LAYOUTS = {
    'employee' => {
      'grid' => [
        { 'id' => 'leave_balances',   'x' => 0, 'y' => 0, 'w' => 6, 'h' => 3 },
        { 'id' => 'upcoming_leaves',  'x' => 6, 'y' => 0, 'w' => 6, 'h' => 3 },
        { 'id' => 'personal_planning','x' => 0, 'y' => 3, 'w' => 12,'h' => 5 },
        { 'id' => 'pending_requests', 'x' => 0, 'y' => 8, 'w' => 6, 'h' => 3 },
        { 'id' => 'my_performance',   'x' => 6, 'y' => 8, 'w' => 6, 'h' => 3 },
        { 'id' => 'quick_links',      'x' => 0, 'y' => 11,'w' => 6, 'h' => 5 }
      ],
      'hidden' => []
    },
    'manager' => {
      'grid' => [
        { 'id' => 'trial_period_alerts',  'x' => 0, 'y' => 0, 'w' => 4, 'h' => 3 },
        { 'id' => 'pending_approvals',    'x' => 4, 'y' => 0, 'w' => 4, 'h' => 3 },
        { 'id' => 'absences_today',       'x' => 8, 'y' => 0, 'w' => 4, 'h' => 3 },
        { 'id' => 'team_planning',        'x' => 0, 'y' => 3, 'w' => 12,'h' => 5 },
        { 'id' => 'leave_balances',       'x' => 0, 'y' => 8, 'w' => 4, 'h' => 3 },
        { 'id' => 'upcoming_one_on_ones', 'x' => 4, 'y' => 8, 'w' => 4, 'h' => 3 },
        { 'id' => 'team_performance',     'x' => 8, 'y' => 8, 'w' => 4, 'h' => 3 },
        { 'id' => 'my_performance',       'x' => 0, 'y' => 11,'w' => 6, 'h' => 3 },
        { 'id' => 'pending_requests',     'x' => 6, 'y' => 11,'w' => 6, 'h' => 3 },
        { 'id' => 'quick_links',          'x' => 0, 'y' => 14,'w' => 6, 'h' => 5 }
      ],
      'hidden' => []
    },
    'hr' => {
      'grid' => [
        { 'id' => 'trial_period_alerts', 'x' => 0, 'y' => 0, 'w' => 6, 'h' => 3 },
        { 'id' => 'absences_today',      'x' => 6, 'y' => 0, 'w' => 6, 'h' => 3 },
        { 'id' => 'active_onboardings',  'x' => 0, 'y' => 3, 'w' => 12,'h' => 5 },
        { 'id' => 'leave_balances',      'x' => 0, 'y' => 8, 'w' => 6, 'h' => 3 },
        { 'id' => 'pending_requests',    'x' => 6, 'y' => 8, 'w' => 6, 'h' => 3 },
        { 'id' => 'my_performance',      'x' => 0, 'y' => 11,'w' => 6, 'h' => 3 },
        { 'id' => 'quick_links',         'x' => 6, 'y' => 11,'w' => 6, 'h' => 3 }
      ],
      'hidden' => []
    },
    'admin' => {
      'grid' => [
        { 'id' => 'trial_period_alerts', 'x' => 0, 'y' => 0, 'w' => 6, 'h' => 3 },
        { 'id' => 'absences_today',      'x' => 6, 'y' => 0, 'w' => 6, 'h' => 3 },
        { 'id' => 'active_onboardings',  'x' => 0, 'y' => 3, 'w' => 12,'h' => 5 },
        { 'id' => 'leave_balances',      'x' => 0, 'y' => 8, 'w' => 6, 'h' => 3 },
        { 'id' => 'pending_requests',    'x' => 6, 'y' => 8, 'w' => 6, 'h' => 3 },
        { 'id' => 'my_performance',      'x' => 0, 'y' => 11,'w' => 6, 'h' => 3 },
        { 'id' => 'quick_links',         'x' => 6, 'y' => 11,'w' => 6, 'h' => 3 }
      ],
      'hidden' => []
    }
  }.freeze

  # Mobile layout: 1-column grid (w=1 always), stacked vertically.
  DASHBOARD_DEFAULT_LAYOUTS_MOBILE = {
    'employee' => {
      'grid' => [
        { 'id' => 'leave_balances',   'x' => 0, 'y' => 0,  'w' => 1, 'h' => 3 },
        { 'id' => 'upcoming_leaves',  'x' => 0, 'y' => 3,  'w' => 1, 'h' => 3 },
        { 'id' => 'personal_planning','x' => 0, 'y' => 6,  'w' => 1, 'h' => 4 },
        { 'id' => 'pending_requests', 'x' => 0, 'y' => 10, 'w' => 1, 'h' => 3 },
        { 'id' => 'quick_links',      'x' => 0, 'y' => 13, 'w' => 1, 'h' => 4 }
      ],
      'hidden' => []
    },
    'manager' => {
      'grid' => [
        { 'id' => 'trial_period_alerts',  'x' => 0, 'y' => 0,  'w' => 1, 'h' => 3 },
        { 'id' => 'pending_approvals',    'x' => 0, 'y' => 3,  'w' => 1, 'h' => 3 },
        { 'id' => 'absences_today',       'x' => 0, 'y' => 6,  'w' => 1, 'h' => 3 },
        { 'id' => 'leave_balances',       'x' => 0, 'y' => 9,  'w' => 1, 'h' => 3 },
        { 'id' => 'quick_links',          'x' => 0, 'y' => 12, 'w' => 1, 'h' => 4 }
      ],
      'hidden' => []
    },
    'hr' => {
      'grid' => [
        { 'id' => 'trial_period_alerts', 'x' => 0, 'y' => 0,  'w' => 1, 'h' => 3 },
        { 'id' => 'absences_today',      'x' => 0, 'y' => 3,  'w' => 1, 'h' => 3 },
        { 'id' => 'leave_balances',      'x' => 0, 'y' => 6,  'w' => 1, 'h' => 3 },
        { 'id' => 'pending_requests',    'x' => 0, 'y' => 9,  'w' => 1, 'h' => 3 },
        { 'id' => 'quick_links',         'x' => 0, 'y' => 12, 'w' => 1, 'h' => 4 }
      ],
      'hidden' => []
    },
    'admin' => {
      'grid' => [
        { 'id' => 'trial_period_alerts', 'x' => 0, 'y' => 0,  'w' => 1, 'h' => 3 },
        { 'id' => 'absences_today',      'x' => 0, 'y' => 3,  'w' => 1, 'h' => 3 },
        { 'id' => 'leave_balances',      'x' => 0, 'y' => 6,  'w' => 1, 'h' => 3 },
        { 'id' => 'pending_requests',    'x' => 0, 'y' => 9,  'w' => 1, 'h' => 3 },
        { 'id' => 'quick_links',         'x' => 0, 'y' => 12, 'w' => 1, 'h' => 4 }
      ],
      'hidden' => []
    }
  }.freeze

  def dashboard_layout
    stored = settings.fetch('dashboard_layout', nil)
    return default_dashboard_layout if stored.blank?

    # New GridStack format: has 'grid' key
    if stored['grid'].present?
      default_ids = default_dashboard_layout['grid'].map { |c| c['id'] }
      stored_ids  = stored['grid'].map { |c| c['id'] }

      # Merge: add new permitted cards not yet in stored layout (new role cards, new features)
      missing = (default_ids - stored_ids).filter_map do |id|
        next unless dashboard_card_permitted?(id)
        default_dashboard_layout['grid'].find { |c| c['id'] == id }
      end

      grid = stored['grid'].select { |c| dashboard_card_permitted?(c['id']) } + missing
      { 'grid' => grid, 'hidden' => stored['hidden'] || [] }
    else
      # Legacy format (order/sizes) — fall back to default GridStack layout
      default_dashboard_layout
    end
  end

  def dashboard_layout=(layout_hash)
    self.settings = settings.merge('dashboard_layout' => layout_hash)
  end

  def dashboard_layout_mobile
    stored = settings.fetch('dashboard_layout_mobile', nil)
    return default_dashboard_layout_mobile if stored.blank?
    stored
  end

  def dashboard_layout_mobile=(layout_hash)
    self.settings = settings.merge('dashboard_layout_mobile' => layout_hash)
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

  # AR Encryption uses non-deterministic mode — DB-level unique index is not possible.
  # Uniqueness is enforced by decrypting and comparing all org NIRs in Ruby.
  # Acceptable at current scale (org employees << 10k); revisit if perf becomes an issue.
  def nir_unique_within_organization
    conflict = organization.employees
                           .where.not(id: id.to_i)
                           .find { |e| e.nir == nir }
    errors.add(:nir, "est déjà utilisé par un autre employé") if conflict
  end

  def default_dashboard_layout
    base = DASHBOARD_DEFAULT_LAYOUTS.fetch(role, DASHBOARD_DEFAULT_LAYOUTS['employee']).deep_dup
    base['grid'].select! { |card| dashboard_card_permitted?(card['id']) }
    base
  end

  def default_dashboard_layout_mobile
    base = DASHBOARD_DEFAULT_LAYOUTS_MOBILE.fetch(role, DASHBOARD_DEFAULT_LAYOUTS_MOBILE['employee']).deep_dup
    base['grid'].select! { |card| dashboard_card_permitted?(card['id']) }
    base
  end
end
