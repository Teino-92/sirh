# frozen_string_literal: true

class Notification < ApplicationRecord
  acts_as_tenant :organization

  belongs_to :employee

  validates :title, :notification_type, presence: true
  validate :employee_belongs_to_same_organization

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  TYPES = %w[
    schedule_created
    schedule_updated
    leave_approved
    leave_rejected
    hours_validated
    hours_rejected
    system
  ].freeze

  validates :notification_type, inclusion: { in: TYPES }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update(read_at: Time.current) if unread?
  end

  def related_object
    return nil unless related_type && related_id
    related_type.constantize.find_by(id: related_id)
  end

  private

  def employee_belongs_to_same_organization
    return unless employee && organization_id

    if employee.organization_id != organization_id
      errors.add(:employee, 'must belong to the same organization')
    end
  end
end
