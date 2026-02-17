class ActionItem < ApplicationRecord
  # Multi-tenancy
  belongs_to :organization
  acts_as_tenant :organization

  # Parent relationship
  belongs_to :one_on_one

  # Responsibility
  belongs_to :responsible, class_name: 'Employee'

  # Optional link to objective
  belongs_to :objective, optional: true

  # Enums
  enum status: {
    pending: 'pending',
    in_progress: 'in_progress',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  enum responsible_type: {
    manager: 'manager',
    employee: 'employee'
  }

  # Validations
  validates :description, presence: true, length: { maximum: 1000 }
  validates :deadline, presence: true
  validates :status, presence: true
  validates :responsible_type, presence: true, inclusion: { in: responsible_types.keys }

  # Scopes
  scope :active, -> { where(status: [:pending, :in_progress]) }
  scope :overdue, -> { active.where('deadline < ?', Date.current) }
  scope :for_responsible, ->(employee) { where(responsible: employee) }

  # Instance methods
  def overdue?
    active? && deadline < Date.current
  end

  def active?
    pending? || in_progress?
  end

  def complete!
    update!(status: :completed, completed_at: Time.current)
  end
end
