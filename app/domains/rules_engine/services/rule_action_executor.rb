# frozen_string_literal: true

# Executes a single action from a BusinessRule.
#
# Action formats:
#   { "type" => "require_approval", "role" => "manager", "order" => 1 }
#   { "type" => "auto_approve" }
#   { "type" => "block", "reason" => "Période bloquée" }
#   { "type" => "notify", "role" => "hr", "message" => "...", "subject" => "..." }
#   { "type" => "notify", "employee_id" => 42, "message" => "...", "subject" => "..." }
#   { "type" => "escalate_after", "role" => "manager", "order" => 1,
#     "hours" => 24, "escalate_to_role" => "hr" }
class RuleActionExecutor
  Result = Struct.new(:type, :payload, keyword_init: true)

  def initialize(action, resource, organization)
    @action       = action
    @resource     = resource
    @organization = organization
  end

  # Returns a Result describing what was done.
  def execute
    case @action['type']
    when 'require_approval' then create_approval_step
    when 'auto_approve'     then Result.new(type: :auto_approve, payload: {})
    when 'block'            then Result.new(type: :block,        payload: { reason: @action['reason'] })
    when 'notify'           then dispatch_notification
    when 'escalate_after'   then create_escalating_approval_step
    else
      Result.new(type: :unknown, payload: { action_type: @action['type'] })
    end
  end

  private

  def create_approval_step
    step = ApprovalStep.create!(
      organization:  @organization,
      resource_type: @resource.class.name,
      resource_id:   @resource.id,
      step_order:    @action['order'] || 1,
      required_role: @action['role'],
      status:        'pending'
    )
    Result.new(type: :require_approval, payload: { step_id: step.id, role: step.required_role, order: step.step_order })
  end

  def create_escalating_approval_step
    hours = @action['hours'].to_i
    step  = ApprovalStep.create!(
      organization:        @organization,
      resource_type:       @resource.class.name,
      resource_id:         @resource.id,
      step_order:          @action['order'] || 1,
      required_role:       @action['role'],
      status:              'pending',
      escalate_after_hours: hours,
      escalate_to_role:    @action['escalate_to_role'],
      escalate_at:         Time.current + hours.hours
    )
    RulesEngine::ApprovalEscalationJob.set(wait: hours.hours).perform_later(step.id)
    Result.new(type: :escalate_after, payload: { step_id: step.id, role: step.required_role, escalate_to: @action['escalate_to_role'], hours: hours })
  end

  def dispatch_notification
    count = NotificationDispatcher.new(@action, @resource, @organization).dispatch
    Result.new(type: :notify, payload: { recipients_count: count, role: @action['role'], message: @action['message'] })
  end
end
