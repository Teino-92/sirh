# frozen_string_literal: true

# One step in an N-level approval chain for any approvable resource.
#
# Steps are created by RulesEngine when a "require_approval" action fires.
# They are processed in step_order — each step must be approved before
# the next one becomes actionable.
class ApprovalStep < ApplicationRecord
  acts_as_tenant :organization

  STATUSES = %w[pending approved rejected skipped].freeze

  belongs_to :organization
  belongs_to :approved_by, class_name: 'Employee', optional: true
  belongs_to :rejected_by, class_name: 'Employee', optional: true

  validates :resource_type, presence: true
  validates :resource_id,   presence: true
  validates :step_order,    presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :required_role, presence: true
  validates :status,        inclusion: { in: STATUSES }

  scope :for_resource,       ->(type, id) { where(resource_type: type, resource_id: id).order(:step_order) }
  scope :pending,            -> { where(status: 'pending') }
  scope :pending_escalation, -> { pending.where(escalated: false).where('escalate_at <= ?', Time.current) }

  def self.current_step(type, id)
    where(resource_type: type, resource_id: id, status: 'pending').order(:step_order).first
  end

  def approve!(employee, comment: nil)
    update!(
      status:      'approved',
      approved_by: employee,
      approved_at: Time.current,
      comment:     comment
    )
  end

  def reject!(employee, comment: nil)
    update!(
      status:      'rejected',
      rejected_by: employee,
      rejected_at: Time.current,
      comment:     comment
    )
  end

  def pending?     = status == 'pending'
  def approved?    = status == 'approved'
  def rejected?    = status == 'rejected'
  def escalatable? = pending? && !escalated? && escalate_at.present? && escalate_at <= Time.current

  def escalate!(new_step)
    update!(escalated: true)
    new_step
  end
end
