# frozen_string_literal: true

# Evaluates all active BusinessRules for an organisation on a given trigger.
#
# Usage:
#   # Full execution (post-save) — resource must be persisted
#   results = RulesEngine.new(org).trigger('leave_request.submitted', resource: lr, context: ctx)
#
#   # Validation-only — safe to call on unsaved resources
#   # Only executes 'block' actions, skips require_approval / notify / escalate_after
#   results = RulesEngine.new(org).trigger('leave_request.submitted', resource: lr, context: ctx, mode: :validate)
#
# Returns an array of RuleEngineResult structs describing what happened.
# Logs each execution in rule_executions for audit (skipped in :validate mode to avoid noise).
#
# Feature-flagged: only runs if organization.settings['rules_engine_enabled'] is true.
class RulesEngine
  # Actions safe to execute on unsaved resources (no DB writes on the resource)
  VALIDATION_SAFE_ACTION_TYPES = %w[block].freeze

  RuleEngineResult = Struct.new(:rule, :matched, :actions_executed, keyword_init: true)

  def initialize(organization)
    @organization = organization
  end

  # @param mode [:full, :validate]
  #   :validate — only executes 'block' actions, does not log, safe on unpersisted resources
  #   :full     — executes all actions, logs execution, resource must be persisted
  def trigger(event, resource:, context: {}, mode: :full)
    return [] unless enabled?

    rules = BusinessRule.for_trigger(event)
    rules.map { |rule| evaluate(rule, event, resource, context, mode) }
  end

  private

  def enabled?
    @organization.settings.fetch('rules_engine_enabled', false)
  end

  def evaluate(rule, event, resource, context, mode)
    matched = RuleConditionEvaluator.match_all?(rule.conditions, context)

    actions_executed = matched ? execute_actions(rule, resource, mode) : []

    log_execution(rule, event, resource, context, actions_executed, matched) if mode == :full

    RuleEngineResult.new(rule: rule, matched: matched, actions_executed: actions_executed)
  rescue => e
    Rails.logger.error("[RulesEngine] Rule #{rule.id} failed: #{e.message}")
    log_execution(rule, event, resource, context, [], false, error: e.message) if mode == :full
    RuleEngineResult.new(rule: rule, matched: false, actions_executed: [])
  end

  def execute_actions(rule, resource, mode)
    actions = rule.actions.sort_by { |a| a['order'] || 0 }
    actions = actions.select { |a| VALIDATION_SAFE_ACTION_TYPES.include?(a['type']) } if mode == :validate
    actions.map { |action| RuleActionExecutor.new(action, resource, @organization).execute }
  end

  def log_execution(rule, event, resource, context, actions_executed, matched, error: nil)
    RuleExecution.create!(
      organization:     @organization,
      business_rule:    rule,
      trigger:          event,
      resource_type:    resource.class.name,
      resource_id:      resource.id,
      context:          context,
      actions_executed: actions_executed.map(&:to_h),
      result:           error ? 'failed' : (matched ? 'executed' : 'skipped'),
      error_message:    error
    )
  rescue => e
    # Never let audit logging break the main flow
    Rails.logger.warn("[RulesEngine] Failed to log execution: #{e.message}")
  end
end
