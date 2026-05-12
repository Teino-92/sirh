# frozen_string_literal: true

class ObjectiveTask < ApplicationRecord
  include SameOrganizationValidatable

  belongs_to :organization
  acts_as_tenant :organization

  belongs_to :objective
  belongs_to :assigned_to,  class_name: 'Employee', foreign_key: :assigned_to_id
  belongs_to :completed_by, class_name: 'Employee', foreign_key: :completed_by_id, optional: true
  belongs_to :validated_by, class_name: 'Employee', foreign_key: :validated_by_id, optional: true

  enum status: { todo: 'todo', done: 'done', validated: 'validated' }

  validates :title, presence: true, length: { maximum: 255 }
  validates :assigned_to, presence: true
  validate_same_organization :objective
  validate_same_organization :assigned_to

  default_scope { order(:position, :created_at) }

  scope :pending_validation, -> { where(status: 'done') }

  def complete!(employee)
    raise "already validated — cannot mark done" if validated?
    update!(status: :done, completed_at: Time.current, completed_by: employee)
  end

  def validate_task!(manager)
    raise "not done yet — employee must complete first" unless done?
    update!(status: :validated, validated_at: Time.current, validated_by: manager)
  end
end
