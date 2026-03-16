# frozen_string_literal: true

# Evaluates a single condition against a context hash.
#
# Condition format:
#   { "field" => "days_count", "operator" => "gte", "value" => 5 }
#
# Supported operators: eq, neq, gt, gte, lt, lte, in, between, present, blank
#
# between: value must be a 2-element array [min, max] (inclusive)
# present: matches if field is present (non-nil, non-empty) — no value needed
# blank:   matches if field is blank (nil or empty) — no value needed
class RuleConditionEvaluator
  # Operators that can evaluate nil/blank values (don't need actual to be present).
  # 'neq' is included because nil != any_value is semantically true.
  NULL_SAFE_OPERATORS = %w[present blank neq].freeze

  OPERATORS = {
    'eq'      => ->(a, b) { a == b },
    'neq'     => ->(a, b) { a != b },
    'gt'      => ->(a, b) { a > b },
    'gte'     => ->(a, b) { a >= b },
    'lt'      => ->(a, b) { a < b },
    'lte'     => ->(a, b) { a <= b },
    'in'      => ->(a, b) { Array(b).include?(a) },
    'between' => ->(a, b) { (lo, hi) = b; a >= lo && a <= hi },
    'present' => ->(a, _) { a.present? },
    'blank'   => ->(a, _) { a.blank? }
  }.freeze

  # Returns true if ALL conditions match the context.
  def self.match_all?(conditions, context)
    conditions.all? { |condition| new(condition, context).match? }
  end

  def initialize(condition, context)
    @field    = condition['field']
    @operator = condition['operator']
    @value    = condition['value']
    @context  = context
  end

  def match?
    comparator = OPERATORS[@operator]
    return false unless comparator

    actual = @context[@field]

    # present/blank can evaluate nil — all other operators short-circuit on nil
    return false if actual.nil? && !NULL_SAFE_OPERATORS.include?(@operator)

    value = @operator == 'between' ? coerce_pair(@value) : coerce(@value)
    comparator.call(coerce(actual), value)
  rescue ArgumentError, TypeError
    false
  end

  private

  def coerce(val)
    case val
    when String
      Integer(val) rescue Float(val) rescue val
    else
      val
    end
  end

  def coerce_pair(val)
    arr = Array(val)
    [coerce(arr[0]), coerce(arr[1])]
  end
end
