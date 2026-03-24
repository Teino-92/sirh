# frozen_string_literal: true

# Calculates complementary hours (heures complémentaires) for part-time employees.
#
# French labor law (Code du travail Art. L3123-20 to L3123-28):
#   - Legal regime:       max 1/10 (10%) of contractual weekly hours
#   - Conventional regime: max 1/3 (33%) of contractual weekly hours (requires collective agreement)
#   - Absolute ceiling:   never reach or exceed 35h/week (requalification as full-time)
#
# Only applies to part-time employees (work_schedule.weekly_hours < 35).
#
# Usage:
#   result = ComplementaryHoursCalculatorService.new(employee, week_start: Date.current.beginning_of_week).call
#   result.applicable?       # false if full-time
#   result.over_legal?       # true if complementary > legal limit
#   result.near_ceiling?     # true if 1h or less from requalification ceiling
class ComplementaryHoursCalculatorService
  LEGAL_RATIO        = (1.0 / 10).freeze  # Art. L3123-28 — 10%
  CONVENTIONAL_RATIO = (1.0 / 3).freeze   # Art. L3123-25 — 33%
  REQUALIFICATION_CEILING = 35.0.freeze
  SAFETY_MARGIN      = 1.0.freeze         # Stay 1h below 35h to avoid grey zones

  Result = Struct.new(
    :worked,             # Float — total hours worked that week
    :contractual,        # Float — from work_schedule.weekly_hours
    :complementary,      # Float — hours beyond contractual (floored at 0)
    :legal_limit,        # Float — contractual × 10%
    :conventional_limit, # Float — contractual × 33%
    :active_limit,       # Float — the limit in force per org regime
    :ceiling,            # Float — effective ceiling (min of 34h or contractual + active_limit)
    :regime,             # String — 'legal' or 'conventional'
    :over_legal,         # Boolean
    :over_conventional,  # Boolean
    :near_ceiling,       # Boolean — worked >= ceiling - 1.0
    :applicable,         # Boolean — false when employee is full-time
    keyword_init: true
  )

  def initialize(employee, week_start:)
    @employee   = employee
    @week_start = week_start.beginning_of_week
    @week_end   = @week_start + 6.days
  end

  def call
    return inapplicable_result unless applicable?

    comp  = complementary_hours
    limit = active_limit

    Result.new(
      worked:             worked_hours,
      contractual:        contractual_hours,
      complementary:      comp,
      legal_limit:        legal_limit,
      conventional_limit: conventional_limit,
      active_limit:       limit,
      ceiling:            ceiling,
      regime:             regime,
      over_legal:         comp > legal_limit,
      over_conventional:  comp > conventional_limit,
      near_ceiling:       worked_hours >= (ceiling - SAFETY_MARGIN),
      applicable:         true
    )
  end

  private

  def applicable?
    @employee.work_schedule&.part_time? == true
  end

  def worked_hours
    @worked_hours ||= @employee.time_entries
      .completed
      .for_date_range(@week_start, @week_end)
      .sum('(duration_minutes - COALESCE(break_duration_minutes, 0))')
      .to_f / 60.0
  end

  def contractual_hours
    @contractual_hours ||= @employee.work_schedule.weekly_hours.to_f
  end

  def regime
    @regime ||= @employee.organization.complementary_hours_regime
  end

  def legal_limit
    @legal_limit ||= (contractual_hours * LEGAL_RATIO).round(2)
  end

  def conventional_limit
    @conventional_limit ||= (contractual_hours * CONVENTIONAL_RATIO).round(2)
  end

  def active_limit
    @active_limit ||= regime == 'conventional' ? conventional_limit : legal_limit
  end

  def complementary_hours
    [worked_hours - contractual_hours, 0.0].max.round(2)
  end

  def ceiling
    @ceiling ||= [REQUALIFICATION_CEILING - SAFETY_MARGIN, contractual_hours + active_limit].min.round(2)
  end

  def inapplicable_result
    ch = @employee.work_schedule&.weekly_hours.to_f

    Result.new(
      worked: 0.0, contractual: ch, complementary: 0.0,
      legal_limit: 0.0, conventional_limit: 0.0, active_limit: 0.0,
      ceiling: 0.0, regime: 'legal',
      over_legal: false, over_conventional: false, near_ceiling: false,
      applicable: false
    )
  end
end
