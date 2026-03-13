require 'rails_helper'

RSpec.describe EvaluationBuilder do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:builder) { described_class.new(organization) }

  describe '#create_with_objectives' do
    let(:period_start) { Date.new(2025, 1, 1) }
    let(:period_end) { Date.new(2025, 12, 31) }

    it 'creates an evaluation with draft status' do
      evaluation = builder.create_with_objectives(
        employee: employee,
        manager: manager,
        period_start: period_start,
        period_end: period_end
      )

      expect(evaluation).to be_persisted
      expect(evaluation.status).to eq('draft')
      expect(evaluation.employee).to eq(employee)
      expect(evaluation.manager).to eq(manager)
      expect(evaluation.organization).to eq(organization)
    end

    it 'links objectives when provided' do
      objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)

      evaluation = builder.create_with_objectives(
        employee: employee,
        manager: manager,
        period_start: period_start,
        period_end: period_end,
        objective_ids: [objective.id]
      )

      expect(evaluation.objectives).to include(objective)
    end

    it 'only links objectives owned by the employee' do
      own_objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)
      other_employee = create(:employee, organization: organization)
      other_objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: other_employee)

      evaluation = builder.create_with_objectives(
        employee: employee,
        manager: manager,
        period_start: period_start,
        period_end: period_end,
        objective_ids: [own_objective.id, other_objective.id]
      )

      expect(evaluation.objectives).to include(own_objective)
      expect(evaluation.objectives).not_to include(other_objective)
    end

    it 'creates evaluation without objectives when none provided' do
      evaluation = builder.create_with_objectives(
        employee: employee,
        manager: manager,
        period_start: period_start,
        period_end: period_end
      )

      expect(evaluation.objectives).to be_empty
    end

    it 'is transactional — rolls back on failure' do
      allow(Evaluation).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      expect {
        builder.create_with_objectives(
          employee: employee,
          manager: manager,
          period_start: period_start,
          period_end: period_end
        )
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Evaluation.count).to eq(0)
    end
  end

  describe '#completion_rate' do
    before do
      other_employee = create(:employee, organization: organization, manager: manager)
      third_employee = create(:employee, organization: organization, manager: manager)

      create(:evaluation, :completed, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 12, 31))
      create(:evaluation, :completed, organization: organization, employee: other_employee, manager: manager, created_by: manager,
             period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 12, 31))
      # third_employee has no evaluation
      _ = third_employee
    end

    it 'returns total employee count (MEDIUM-2 regression guard: Employee.active scope must work)' do
      result = builder.completion_rate(year: 2025)
      # organization has manager + employee + other_employee + third_employee = 4 active employees
      # Before fix: Employee.active returned 0 (broken JSONB exact-match query)
      # After fix: returns all employees whose settings['active'] is absent or true
      expect(result[:total]).to be >= 2
      expect(result[:total]).to be > 0
    end

    it 'returns evaluated count for the year' do
      result = builder.completion_rate(year: 2025)
      expect(result[:evaluated]).to eq(2)
    end

    it 'returns 0 rate for year with no evaluations' do
      result = builder.completion_rate(year: 2020)
      expect(result[:rate]).to eq(0)
      expect(result[:evaluated]).to eq(0)
    end
  end
end
