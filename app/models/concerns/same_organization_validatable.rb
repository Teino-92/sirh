# frozen_string_literal: true

# Provides a reusable validation helper to ensure that associated records
# belong to the same organization as the current model.
#
# Usage:
#   validate_same_organization :manager
#   validate_same_organization :employee, :approved_by
#   validate_same_organization :employee, organization_source: :training
module SameOrganizationValidatable
  extend ActiveSupport::Concern

  included do
    # DSL — declared at class level in each model
    def self.validate_same_organization(*associations, organization_source: nil, message: 'must belong to the same organization')
      associations.each do |assoc|
        validate do
          record = public_send(assoc)
          next unless record.present?

          source_org_id = organization_source ? public_send(organization_source)&.organization_id : organization_id
          next unless source_org_id.present?

          unless record.organization_id == source_org_id
            errors.add(assoc, message)
          end
        end
      end
    end
  end
end
