# frozen_string_literal: true

# Provides lightweight JSONB structure validation without external gems.
# Each model calls `validates_jsonb_keys` to declare allowed keys and their types.
#
# Usage:
#   include JsonbValidatable
#   validates_jsonb_keys :settings, allowed: %i[work_week_hours rtt_enabled ...], types: { work_week_hours: Integer }
module JsonbValidatable
  extend ActiveSupport::Concern

  included do
    class_attribute :_jsonb_validators, default: {}
  end

  class_methods do
    # Declares validation rules for a jsonb column.
    # Options:
    #   allowed: array of allowed keys (Symbol or String). Extra keys are rejected.
    #   required: array of keys that must be present and non-nil.
    #   types: hash of key => Class for type checking.
    def validates_jsonb_keys(attribute, allowed: [], required: [], types: {})
      _jsonb_validators[attribute] = { allowed: allowed.map(&:to_s),
                                       required: required.map(&:to_s),
                                       types: types.transform_keys(&:to_s) }

      validate do
        rules = self.class._jsonb_validators[attribute]
        value = public_send(attribute)
        next if value.nil?

        # Skip validation for non-Hash values (e.g. legacy string data in DB)
        next unless value.is_a?(Hash)

        # Unknown keys (only checked when allowed: was explicitly declared)
        if rules[:allowed].any?
          (value.keys.map(&:to_s) - rules[:allowed]).each do |key|
            errors.add(attribute, :invalid, message: "contient une clé inconnue : #{key}")
          end
        end

        # Required keys
        rules[:required].each do |key|
          if value[key].nil? && value[key.to_sym].nil?
            errors.add(attribute, :blank, message: "clé obligatoire manquante : #{key}")
          end
        end

        # Type checks
        rules[:types].each do |key, expected_type|
          val = value[key] || value[key.to_sym]
          next if val.nil?

          # Boolean special case: Ruby stores true/false as TrueClass/FalseClass
          valid = if expected_type == :boolean
                    val.is_a?(TrueClass) || val.is_a?(FalseClass)
                  else
                    val.is_a?(expected_type)
                  end

          unless valid
            errors.add(attribute, :invalid,
                       message: "#{key} doit être de type #{expected_type} (reçu: #{val.class})")
          end
        end
      end
    end
  end
end
