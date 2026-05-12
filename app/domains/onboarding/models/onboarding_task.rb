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

  scope :pending,             -> { where(status: 'pending') }
  scope :done,                -> { where(status: 'done') }
  scope :completed,           -> { where(status: 'completed') }
  scope :overdue,             -> { where(status: 'pending').where('due_date < ?', Date.current) }
  scope :awaiting_validation, -> { where(status: 'done') }

  def mark_done!(employee)
    raise InvalidTransitionError, "seules les tâches assigned_to_role 'employee' peuvent être marquées faites" unless assigned_to_role == 'employee'
    raise InvalidTransitionError, "déjà complétée" if completed?

    transaction do
      update!(status: :done, completed_at: Time.current, completed_by: employee)
    end
  end

  def validate!(manager)
    raise InvalidTransitionError, "la tâche doit être done avant validation" unless done?

    transaction do
      update!(status: :completed, validated_at: Time.current, validated_by: manager)
    end
  end

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
