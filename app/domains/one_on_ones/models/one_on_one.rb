class OneOnOne < ApplicationRecord
  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  # Core relationships
  belongs_to :manager, class_name: 'Employee'
  belongs_to :employee, class_name: 'Employee'

  # Child resources
  has_many :action_items, dependent: :destroy
  has_many :one_on_one_objectives, dependent: :destroy
  has_many :objectives, through: :one_on_one_objectives

  # Enums
  enum status: {
    scheduled: 'scheduled',
    completed: 'completed',
    cancelled: 'cancelled',
    rescheduled: 'rescheduled'
  }

  # Validations
  validates :scheduled_at, presence: true
  validates :status, presence: true
  validate :manager_different_from_employee
  validate :manager_is_actual_manager
  validate :both_in_same_organization

  # Scopes
  scope :upcoming, -> { where(status: :scheduled).where('scheduled_at >= ?', Time.current).order(:scheduled_at) }
  scope :past, -> { where(status: :completed).order(scheduled_at: :desc) }
  scope :for_manager, ->(manager) { where(manager: manager) }
  scope :for_employee, ->(employee) { where(employee: employee) }
  scope :this_quarter, -> { where('scheduled_at >= ?', Date.current.beginning_of_quarter) }

  # Instance methods
  def complete!(notes:)
    transaction do
      update!(status: :completed, completed_at: Time.current, notes: notes)
      action_items.pending.update_all(updated_at: Time.current)
    end
  end

  def overdue?
    scheduled? && scheduled_at < Time.current
  end

  private

  def manager_different_from_employee
    return unless manager.present? && employee.present?
    return if manager_id != employee_id

    errors.add(:employee, 'cannot be the same as manager')
  end

  def manager_is_actual_manager
    return unless manager.present?
    return if manager.manager?

    errors.add(:manager, 'must have manager role')
  end

  def both_in_same_organization
    return unless manager.present? && employee.present? && organization.present?
    return if manager.organization_id == organization_id && employee.organization_id == organization_id

    errors.add(:base, 'manager and employee must belong to the same organization')
  end
end
