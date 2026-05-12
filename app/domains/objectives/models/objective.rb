class Objective < ApplicationRecord
  include SameOrganizationValidatable

  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  # Core relationships
  belongs_to :owner, polymorphic: true
  belongs_to :manager, class_name: 'Employee'
  belongs_to :created_by, class_name: 'Employee'

  # Optional relationships (loose coupling)
  has_many :evaluation_objectives, dependent: :nullify
  has_many :evaluations, through: :evaluation_objectives
  has_many :one_on_one_objectives, dependent: :nullify
  has_many :one_on_ones, through: :one_on_one_objectives
  has_many :objective_tasks, dependent: :destroy

  # Enums
  enum status: {
    draft: 'draft',
    in_progress: 'in_progress',
    completed: 'completed',
    blocked: 'blocked',
    cancelled: 'cancelled'
  }

  enum priority: {
    low: 'low',
    medium: 'medium',
    high: 'high',
    critical: 'critical'
  }

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :status, presence: true
  validates :owner_type, inclusion: { in: %w[Employee] }
  validates :deadline, presence: true
  validate :deadline_in_future, on: :create
  validate_same_organization :manager
  validate_same_organization :owner

  # Email notification to owner when assigned
  after_create_commit :send_assigned_notification

  # Scopes
  scope :active, -> { where(status: [:draft, :in_progress, :blocked]) }
  scope :overdue, -> { active.where('deadline < ?', Date.current) }
  scope :upcoming, -> { active.where('deadline BETWEEN ? AND ?', Date.current, 30.days.from_now) }
  scope :for_manager, ->(manager) { where(manager: manager) }
  scope :for_owner, ->(owner) { where(owner: owner) }

  # Instance methods
  def overdue?
    active? && deadline < Date.current
  end

  def active?
    draft? || in_progress? || blocked?
  end

  def complete!
    return if completed?
    update!(status: :completed, completed_at: Time.current)
  end

  def progress_percentage
    return nil if objective_tasks.empty?
    validated = objective_tasks.select(&:validated?).count
    total = objective_tasks.count
    (validated.to_f / total * 100).round
  end

  def tasks?
    objective_tasks.loaded? ? objective_tasks.any? : objective_tasks.exists?
  end

  private

  def send_assigned_notification
    # Only notify when the owner is an Employee (not a team) and is different from the creator
    return unless owner.is_a?(Employee) && owner != created_by
    ObjectiveMailer.assigned(self).deliver_later
  end

  def deadline_in_future
    return unless deadline.present? && deadline < Date.current
    errors.add(:deadline, 'must be in the future')
  end
end
