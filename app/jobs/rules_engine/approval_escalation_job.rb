# frozen_string_literal: true

# Scheduled job that fires when an ApprovalStep escalation deadline is reached.
# Creates a new step for the escalation role and marks the original as escalated.
#
# Idempotent: no-op if the step has already been approved, rejected, or escalated.
#
# Note: requires Sidekiq (or a persistent queue adapter) to survive server restarts.
# With queue_adapter = :async (Render free tier), jobs are lost on restart.
# The escalate_at column in DB allows a future cron to recover orphaned escalations.
class RulesEngine::ApprovalEscalationJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveRecord::RecordNotUnique

  # Whitelist of allowed resource types — prevents unsafe constantize on DB values.
  ALLOWED_RESOURCE_TYPES = %w[LeaveRequest].freeze

  def perform(approval_step_id)
    # Load outside tenant scope — step_id is globally unique
    step = ApprovalStep.find(approval_step_id)

    ActsAsTenant.with_tenant(step.organization) do
      # SELECT FOR UPDATE prevents double-escalation on concurrent retries
      ApprovalStep.transaction do
        step = ApprovalStep.lock.find(approval_step_id)

        return if step.approved? || step.rejected? || step.escalated?
        return unless step.escalate_to_role.present?

        # Use max existing step_order + 1 to avoid UniqueViolation
        max_order = ApprovalStep
          .where(resource_type: step.resource_type, resource_id: step.resource_id)
          .maximum(:step_order) || 0

        new_step = ApprovalStep.create!(
          organization:  step.organization,
          resource_type: step.resource_type,
          resource_id:   step.resource_id,
          step_order:    max_order + 1,
          required_role: step.escalate_to_role,
          status:        'pending'
        )

        step.escalate!(new_step)
      end

      resource_klass = ALLOWED_RESOURCE_TYPES.include?(step.resource_type) ? step.resource_type.constantize : nil
      resource = resource_klass&.find_by(id: step.resource_id)
      RulesEngine::NotificationDispatcher.new(
        { 'role' => step.escalate_to_role, 'message' => "Une approbation en attente vous a été escaladée.", 'subject' => "Action requise — Escalade d'approbation" },
        resource,
        step.organization
      ).dispatch
    end
  end
end
