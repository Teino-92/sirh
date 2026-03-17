# frozen_string_literal: true

class OrgMergePreviewService
  MODELS = [
    { model: 'Employee',            label: 'Employés' },
    { model: 'LeaveRequest',        label: 'Demandes de congés' },
    { model: 'LeaveBalance',        label: 'Soldes de congés' },
    { model: 'TimeEntry',           label: 'Pointages' },
    { model: 'OneOnOne',            label: 'Entretiens 1:1' },
    { model: 'Objective',           label: 'Objectifs' },
    { model: 'TrainingAssignment',  label: 'Formations' },
    { model: 'EmployeeOnboarding',  label: 'Onboardings' },
    { model: 'Evaluation',          label: 'Évaluations' },
    { model: 'BusinessRule',        label: 'Règles métier' },
  ].freeze

  def initialize(source_organization:)
    @source_org = source_organization
  end

  def call
    ActsAsTenant.without_tenant do
      MODELS.filter_map do |entry|
        model = entry[:model].constantize
        count = model.where(organization_id: @source_org.id).count
        next if count.zero?
        { label: entry[:label], count: count }
      rescue NameError
        nil
      end
    end
  end
end
