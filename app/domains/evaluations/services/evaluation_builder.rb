class EvaluationBuilder
  def initialize(organization)
    @organization = organization
  end

  def create_with_objectives(employee:, manager:, period_start:, period_end:, objective_ids: [])
    ActsAsTenant.with_tenant(@organization) do
      evaluation = nil

      ActiveRecord::Base.transaction do
        evaluation = Evaluation.create!(
          organization: @organization,
          employee: employee,
          manager: manager,
          created_by: manager,
          period_start: period_start,
          period_end: period_end,
          status: :draft
        )

        if objective_ids.any?
          objectives = Objective.where(id: objective_ids, owner: employee)
          evaluation.objectives << objectives
        end
      end

      evaluation
    end
  end

  def completion_rate(year: Date.current.year)
    ActsAsTenant.with_tenant(@organization) do
      total_employees = @organization.employees.active.count
      evaluated = Evaluation.where(status: :completed).by_period(year).distinct.count(:employee_id)

      {
        total: total_employees,
        evaluated: evaluated,
        rate: total_employees > 0 ? (evaluated.to_f / total_employees * 100).round(1) : 0
      }
    end
  end
end
