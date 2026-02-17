class TrainingAssignment < ApplicationRecord
  # Parent relationship
  belongs_to :training
  belongs_to :employee, class_name: 'Employee'
  belongs_to :assigned_by, class_name: 'Employee'

  # Optional link to objective
  belongs_to :objective, optional: true

  # Enums
  enum status: {
    assigned: 'assigned',
    in_progress: 'in_progress',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  # Validations
  validates :status, presence: true
  validates :assigned_at, presence: true
  validate :assigned_by_in_same_organization
  validate :employee_in_same_organization

  # Scopes
  scope :active, -> { where(status: [:assigned, :in_progress]) }
  scope :overdue, -> { active.where('deadline < ?', Date.current).where.not(deadline: nil) }
  scope :for_employee, ->(employee) { where(employee: employee) }
  scope :for_manager, ->(manager) { where(assigned_by: manager) }
  scope :completed_this_year, -> { where(status: :completed).where('completed_at >= ?', Date.current.beginning_of_year) }

  # Instance methods
  def overdue?
    active? && deadline.present? && deadline < Date.current
  end

  def active?
    assigned? || in_progress?
  end

  def complete!(notes: nil)
    return if completed?
    transaction do
      update!(status: :completed, completed_at: Time.current, completion_notes: notes)
    end
  end

  private

  def assigned_by_in_same_organization
    return unless assigned_by.present? && training.present?
    return if assigned_by.organization_id == training.organization_id

    errors.add(:assigned_by, 'must belong to the same organization as the training')
  end

  def employee_in_same_organization
    return unless employee.present? && training.present?
    return if employee.organization_id == training.organization_id

    errors.add(:employee, 'must belong to the same organization as the training')
  end
end
