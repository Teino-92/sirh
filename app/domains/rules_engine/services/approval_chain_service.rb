# frozen_string_literal: true

# Manages the N-level approval chain for a resource (e.g. LeaveRequest).
#
# Usage:
#   service = ApprovalChainService.new(leave_request)
#   service.advance!(approver: current_employee)   # approve current step
#   service.reject!(approver: current_employee, comment: "Trop longue")
#   service.complete?   # true when all steps approved
#   service.blocked?    # true if any step rejected
class ApprovalChainService
  def initialize(resource)
    @resource     = resource
    @organization = resource.organization
  end

  # Returns all steps for this resource, ordered. Memoized — call reload_steps! if needed.
  def steps
    @steps ||= ApprovalStep.for_resource(@resource.class.name, @resource.id).load
  end

  def reload_steps!
    @steps = nil
    steps
  end

  # Returns the current pending step (nil if chain complete or blocked)
  def current_step
    ApprovalStep.current_step(@resource.class.name, @resource.id)
  end

  # Approve the current step. Returns true if chain is now complete.
  def advance!(approver:, comment: nil)
    step = current_step
    raise "No pending approval step" unless step
    raise "#{approver.role} cannot approve step requiring #{step.required_role}" unless can_approve?(approver, step)


    step.approve!(approver, comment: comment)
    reload_steps!

    @resource.update!(current_approval_step: next_step_order) if @resource.respond_to?(:current_approval_step=)

    complete?
  end

  # Reject the current step — blocks the entire chain.
  def reject!(approver:, comment: nil)
    step = current_step
    raise "No pending approval step" unless step
    raise "#{approver.role} cannot reject step requiring #{step.required_role}" unless can_approve?(approver, step)

    step.reject!(approver, comment: comment)
    false
  end

  # True when all steps are approved
  def complete?
    steps.any? && steps.all?(&:approved?)
  end

  # True when any step is rejected
  def blocked?
    steps.any?(&:rejected?)
  end

  # True when there are steps and none are pending
  def pending?
    steps.any? && steps.any?(&:pending?)
  end

  # Human-readable summary
  def summary
    total    = steps.count
    approved = steps.count(&:approved?)
    "#{approved}/#{total} étapes approuvées"
  end

  private

  def can_approve?(employee, step)
    return true if employee.admin?
    return true if employee.role == step.required_role

    # Check for an active temporary delegation covering the required role
    EmployeeDelegation
      .active_now
      .for_delegatee(employee)
      .exists?(role: step.required_role)
  end

  def next_step_order
    next_step = steps.pending.first
    next_step&.step_order
  end
end
