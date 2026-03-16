# frozen_string_literal: true

# Resolves recipients and dispatches notifications for a rules engine "notify" action.
#
# Action format:
#   { "type" => "notify", "role" => "hr", "message" => "...", "subject" => "..." }
#   { "type" => "notify", "employee_id" => 42, "message" => "...", "subject" => "..." }
#
# Creates in-app Notification records (insert_all) and enqueues a background email job.
class NotificationDispatcher
  DEFAULT_SUBJECT = "Notification Izi-RH"

  def initialize(action, resource, organization)
    @action       = action
    @resource     = resource
    @organization = organization
  end

  # Returns the number of employees notified.
  def dispatch
    # Materialize once — avoid 4 separate SQL queries on the same relation
    employees = resolve_recipients.to_a
    return 0 if employees.empty?

    create_in_app_notifications(employees)
    enqueue_emails(employees)

    employees.size
  end

  private

  def resolve_recipients
    if @action['employee_id'].present?
      Employee.where(id: @action['employee_id'], organization_id: @organization.id)
    elsif @action['role'].present?
      @organization.employees.where(role: @action['role'])
    else
      Employee.none
    end
  end

  def create_in_app_notifications(employees)
    now = Time.current
    records = employees.map do |emp|
      {
        organization_id:   @organization.id,
        employee_id:       emp.id,
        title:             subject,
        message:           @action['message'],
        notification_type: 'rule_engine',
        related_type:      @resource&.class&.name,
        related_id:        @resource&.id,
        read_at:           nil,
        created_at:        now,
        updated_at:        now
      }
    end

    Notification.insert_all(records) if records.any?
  end

  def enqueue_emails(employees)
    RulesEngine::NotificationJob.perform_later(
      employees.map(&:id),
      subject,
      @action['message'].to_s,
      organization_id: @organization.id,
      resource_type:   @resource&.class&.name,
      resource_id:     @resource&.id
    )
  end

  def subject
    @action['subject'].presence || DEFAULT_SUBJECT
  end
end
