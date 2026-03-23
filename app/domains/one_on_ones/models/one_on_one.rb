class OneOnOne < ApplicationRecord
  include SameOrganizationValidatable

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
  validate_same_organization :manager, :employee

  # Scopes
  scope :upcoming, -> { where(status: :scheduled).where('scheduled_at >= ?', Time.current).order(:scheduled_at) }
  scope :past, -> { where(status: :completed).order(scheduled_at: :desc) }
  scope :for_manager, ->(manager) { where(manager: manager) }
  scope :for_employee, ->(employee) { where(employee: employee) }
  scope :this_quarter, -> { where('scheduled_at >= ?', Date.current.beginning_of_quarter) }

  # Calendar integration — fire webhook when a 1:1 is created or rescheduled
  after_create_commit  :notify_calendar_webhook
  after_update_commit  :notify_calendar_webhook_if_rescheduled

  # Email notifications to employee
  after_create_commit  :send_scheduled_notification
  after_update_commit  :send_status_change_notification

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

  def notify_calendar_webhook
    fire_calendar_webhook('one_on_one.scheduled')
  end

  def notify_calendar_webhook_if_rescheduled
    return unless saved_change_to_scheduled_at? || saved_change_to_status?
    fire_calendar_webhook('one_on_one.rescheduled')
  end

  def send_scheduled_notification
    OneOnOneMailer.scheduled(self).deliver_later
  end

  def send_status_change_notification
    if saved_change_to_scheduled_at?
      OneOnOneMailer.rescheduled(self).deliver_later
    elsif saved_change_to_status? && cancelled?
      OneOnOneMailer.cancelled(self).deliver_later
    end
  end

  def fire_calendar_webhook(event_name)
    payload = {
      id:           id,
      type:         'one_on_one',
      manager:      { id: manager_id, name: manager.full_name },
      employee:     { id: employee_id, name: employee.full_name },
      scheduled_at: scheduled_at&.iso8601,
      agenda:       agenda,
      status:       status,
      calendar_event_id: metadata['calendar_event_id']
    }
    CalendarWebhookJob.perform_later(event_name, 'OneOnOne', id, payload)
  end

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

end
