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

  # Training relationships
  has_many :training_assignments, dependent: :destroy
  has_many :trainings, through: :training_assignments
  has_many :assigned_trainings, class_name: 'TrainingAssignment', foreign_key: :assigned_by_id, dependent: :nullify

  validates :first_name, :last_name, :contract_type, :start_date, presence: true
  validates :role, presence: true, inclusion: { in: %w[employee manager hr admin] }

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

  def tenure_in_months
    ((Time.current.to_date - start_date) / 30).to_i
  end

  # Team members this employee manages
  def team_members
    return Employee.none unless manager?

    Employee.where(manager_id: id)
  end
end
