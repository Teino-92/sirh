# frozen_string_literal: true

class OnboardingTask < ApplicationRecord
  belongs_to :onboarding
  belongs_to :organization
  acts_as_tenant :organization

  belongs_to :assigned_to,  class_name: 'Employee', optional: true, foreign_key: :assigned_to_id
  belongs_to :completed_by, class_name: 'Employee', optional: true, foreign_key: :completed_by_id

  TASK_TYPES    = OnboardingTemplateTask::TASK_TYPES
  ASSIGNED_ROLES = OnboardingTemplateTask::ASSIGNED_ROLES

  enum status: {
    pending:   'pending',
    completed: 'completed',
    overdue:   'overdue'
  }

  validates :title,            presence: true, length: { maximum: 255 }
  validates :due_date,         presence: true
  validates :assigned_to_role, inclusion: { in: ASSIGNED_ROLES }
  validates :task_type,        inclusion: { in: TASK_TYPES }

  scope :pending,   -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :overdue,   -> { where(status: 'pending').where('due_date < ?', Date.current) }

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

  # Soft-linked record via metadata — returns nil gracefully if deleted
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
