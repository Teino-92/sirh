# frozen_string_literal: true

# Validates leave requests against French labor law and organization policies.
class LeaveRequestValidator
  def initialize(employee, settings)
    @employee     = employee
    @organization = employee.organization
    @settings     = settings
  end

  def validate(leave_request)
    errors = []

    errors << "Solde insuffisant pour #{leave_request.leave_type}" unless sufficient_balance?(leave_request)

    if leave_request.leave_type == 'CP'
      if in_summer_period?(leave_request) && !meets_consecutive_requirement?(leave_request)
        min_days = @settings.get(:minimum_consecutive_leave_days)
        errors << "Vous devez prendre au moins #{min_days} jours consécutifs entre le 1er mai et le 31 octobre"
      end

      if requesting_expired_cp?(leave_request)
        day   = @settings.get(:cp_expiry_day)
        month = Date::MONTHNAMES[@settings.get(:cp_expiry_month)]
        errors << "Ces congés payés ont expiré. Les CP doivent être pris avant le #{day} #{month}."
      end
    end

    errors << "Conflit avec les congés d'un autre membre de l'équipe" if leave_request.conflicts_with_team?

    # Rules engine — only runs if enabled for this organisation (feature flag)
    errors.concat(rules_engine_errors(leave_request))

    errors
  end

  def can_auto_approve?(leave_request)
    return false unless leave_request.leave_type == 'CP'

    role_auto = @organization.group_policies.dig('auto_approve_leave_by_role', @employee.role)
    if ActiveRecord::Type::Boolean.new.cast(role_auto) == true
      return @employee.leave_balances.find_by(leave_type: 'CP')&.balance.to_f >= leave_request.days_count
    end

    threshold    = @settings.get(:auto_approve_threshold_days)
    max_days     = @settings.get(:auto_approve_max_request_days)
    has_balance  = @employee.leave_balances.find_by(leave_type: 'CP')&.balance.to_f >= threshold
    short_enough = leave_request.days_count <= max_days
    no_conflicts = !leave_request.conflicts_with_team?

    has_balance && short_enough && no_conflicts
  end

  private

  def sufficient_balance?(leave_request)
    balance = @employee.leave_balances.find_by(leave_type: leave_request.leave_type)
    balance&.balance.to_f >= leave_request.days_count
  end

  def in_summer_period?(leave_request)
    summer_start = Date.new(leave_request.start_date.year, 5, 1)
    summer_end   = Date.new(leave_request.start_date.year, 10, 31)
    leave_request.start_date.between?(summer_start, summer_end)
  end

  def meets_consecutive_requirement?(leave_request)
    leave_request.days_count >= @settings.get(:minimum_consecutive_leave_days)
  end

  def requesting_expired_cp?(leave_request)
    balance = @employee.leave_balances.find_by(leave_type: 'CP')
    balance&.expired?
  end

  def rules_engine_errors(leave_request)
    return [] unless @organization.settings.fetch('rules_engine_enabled', false)

    context = {
      'leave_type'  => leave_request.leave_type,
      'days_count'  => leave_request.days_count,
      'employee_id' => @employee.id,
      'role'        => @employee.role,
      'start_date'  => leave_request.start_date&.to_s,
      'end_date'    => leave_request.end_date&.to_s
    }

    # :validate mode — only evaluates 'block' actions, safe on unpersisted resources.
    # require_approval / notify / escalate_after are triggered post-save by the caller.
    results = RulesEngine.new(@organization).trigger(
      'leave_request.submitted',
      resource: leave_request,
      context:  context,
      mode:     :validate
    )

    results.select(&:matched).flat_map(&:actions_executed)
           .select { |r| r.type == :block }
           .map    { |r| r.payload[:reason] || "Demande bloquée par une règle métier" }
  end
end
