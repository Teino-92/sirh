require 'rails_helper'

RSpec.describe EvaluationPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:hr) { create(:employee, organization: organization, role: 'hr') }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
  let(:other_employee) { create(:employee, organization: organization, manager: other_manager) }

  subject { described_class }

  describe 'Scope' do
    let!(:manager_evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end
    let!(:other_evaluation) do
      create(:evaluation, organization: organization, employee: other_employee, manager: other_manager, created_by: other_manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end
    let!(:employee_own_evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: other_manager, created_by: other_manager,
             period_start: Date.new(2024, 1, 1), period_end: Date.new(2024, 12, 31))
    end

    context 'as HR' do
      it 'returns all evaluations in organization' do
        resolved = EvaluationPolicy::Scope.new(hr, Evaluation).resolve
        expect(resolved).to include(manager_evaluation, other_evaluation, employee_own_evaluation)
      end
    end

    context 'as manager' do
      it 'returns evaluations managed by or participated in' do
        resolved = EvaluationPolicy::Scope.new(manager, Evaluation).resolve
        expect(resolved).to include(manager_evaluation)
        expect(resolved).not_to include(other_evaluation)
      end
    end

    context 'as employee' do
      it 'returns only evaluations for the employee' do
        resolved = EvaluationPolicy::Scope.new(employee, Evaluation).resolve
        expect(resolved).to include(manager_evaluation, employee_own_evaluation)
        expect(resolved).not_to include(other_evaluation)
      end
    end
  end

  permissions :create? do
    it 'allows HR to create evaluations' do
      expect(subject).to permit(hr, Evaluation.new)
    end

    it 'allows managers to create evaluations' do
      expect(subject).to permit(manager, Evaluation.new)
    end

    it 'denies employees from creating evaluations' do
      expect(subject).not_to permit(employee, Evaluation.new)
    end
  end

  permissions :update? do
    let(:evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end

    it 'allows HR to update any evaluation' do
      expect(subject).to permit(hr, evaluation)
    end

    it 'allows the manager of the evaluation to update it' do
      expect(subject).to permit(manager, evaluation)
    end

    it 'denies another manager from updating the evaluation' do
      expect(subject).not_to permit(other_manager, evaluation)
    end

    it 'denies employees from updating evaluations' do
      expect(subject).not_to permit(employee, evaluation)
    end
  end

  permissions :destroy? do
    let(:evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end

    it 'allows HR to destroy any evaluation' do
      expect(subject).to permit(hr, evaluation)
    end

    it 'allows the manager of the evaluation to destroy it' do
      expect(subject).to permit(manager, evaluation)
    end

    it 'denies employees from destroying evaluations' do
      expect(subject).not_to permit(employee, evaluation)
    end
  end

  permissions :submit_self_review? do
    let(:evaluation) do
      create(:evaluation, :employee_review_pending, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end

    it 'allows the employee to submit self review when pending' do
      expect(subject).to permit(employee, evaluation)
    end

    it 'denies manager from submitting self review' do
      expect(subject).not_to permit(manager, evaluation)
    end

    it 'denies employee when not in employee_review_pending status' do
      evaluation.update!(status: :draft)
      expect(subject).not_to permit(employee, evaluation)
    end
  end

  permissions :submit_manager_review? do
    let(:evaluation) do
      create(:evaluation, :manager_review_pending, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end

    it 'allows the manager to submit manager review when pending' do
      expect(subject).to permit(manager, evaluation)
    end

    it 'allows HR to submit manager review' do
      expect(subject).to permit(hr, evaluation)
    end

    it 'denies employee from submitting manager review' do
      expect(subject).not_to permit(employee, evaluation)
    end

    it 'denies manager when not in manager_review_pending status' do
      evaluation.update!(status: :draft)
      expect(subject).not_to permit(manager, evaluation)
    end
  end

  permissions :complete? do
    let(:evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
             period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
    end

    it 'allows HR to complete evaluations' do
      expect(subject).to permit(hr, evaluation)
    end

    it 'allows the manager to complete evaluations' do
      expect(subject).to permit(manager, evaluation)
    end

    it 'denies employees from completing evaluations' do
      expect(subject).not_to permit(employee, evaluation)
    end
  end
end
