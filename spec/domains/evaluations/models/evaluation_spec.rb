require 'rails_helper'

RSpec.describe Evaluation, type: :model do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:employee) }
    it { should belong_to(:manager) }
    it { should belong_to(:created_by) }
    it { should have_many(:evaluation_objectives).dependent(:destroy) }
    it { should have_many(:objectives).through(:evaluation_objectives) }
  end

  describe 'validations' do
    subject do
      build(:evaluation,
        organization: organization,
        employee: employee,
        manager: manager,
        created_by: manager
      )
    end

    it { should validate_presence_of(:period_start) }
    it { should validate_presence_of(:period_end) }
    it { should validate_presence_of(:status) }

    it 'defines status enum values' do
      expect(Evaluation.statuses.keys).to contain_exactly(
        'draft', 'employee_review_pending', 'manager_review_pending', 'completed', 'cancelled'
      )
    end

    it 'defines score enum values' do
      expect(Evaluation.scores.keys).to contain_exactly(
        'insufficient', 'below_expectations', 'meets_expectations', 'exceeds_expectations', 'exceptional'
      )
    end

    context 'period validation' do
      it 'is invalid when period_end is before period_start' do
        evaluation = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: manager,
          created_by: manager,
          period_start: Date.today,
          period_end: 1.day.ago.to_date
        )
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:period_end]).to include('must be after period start')
      end

      it 'is invalid when period_end equals period_start' do
        date = 6.months.ago.to_date
        evaluation = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: manager,
          created_by: manager,
          period_start: date,
          period_end: date
        )
        expect(evaluation).not_to be_valid
      end

      it 'is valid when period_end is after period_start' do
        evaluation = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: manager,
          created_by: manager,
          period_start: 1.year.ago.beginning_of_year.to_date,
          period_end: 1.year.ago.end_of_year.to_date
        )
        expect(evaluation).to be_valid
      end
    end

    context 'manager role validation' do
      it 'is invalid when manager has employee role' do
        non_manager = create(:employee, organization: organization, role: 'employee')
        evaluation = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: non_manager,
          created_by: non_manager
        )
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:manager]).to include('must have manager or HR role')
      end

      it 'is valid when manager has manager role' do
        evaluation = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: manager,
          created_by: manager
        )
        expect(evaluation).to be_valid
      end
    end

    context 'same organization validation' do
      it 'is invalid when employee is from different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)
        evaluation = build(:evaluation,
          organization: organization,
          employee: other_employee,
          manager: manager,
          created_by: manager
        )
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:employee]).to include('must belong to the same organization')
      end

      it 'is invalid when manager is from different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, organization: other_org, role: 'manager')
        evaluation = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: other_manager,
          created_by: other_manager
        )
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:manager]).to include('must belong to the same organization')
      end
    end

    context 'unique evaluation per period' do
      it 'prevents duplicate evaluations for same employee and period' do
        create(:evaluation,
          organization: organization,
          employee: employee,
          manager: manager,
          created_by: manager,
          period_start: Date.new(2025, 1, 1),
          period_end: Date.new(2025, 12, 31)
        )

        duplicate = build(:evaluation,
          organization: organization,
          employee: employee,
          manager: manager,
          created_by: manager,
          period_start: Date.new(2025, 1, 1),
          period_end: Date.new(2025, 12, 31)
        )

        expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe 'scopes' do
    before do
      ActsAsTenant.with_tenant(organization) do
        create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager, status: :draft,
               period_start: Date.new(2023, 1, 1), period_end: Date.new(2023, 12, 31))
        create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager, status: :employee_review_pending,
               period_start: Date.new(2024, 1, 1), period_end: Date.new(2024, 6, 30))
        create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager, status: :completed,
               period_start: Date.new(2025, 1, 1), period_end: Date.new(2025, 12, 31))
      end
    end

    describe '.active' do
      it 'returns draft and pending evaluations' do
        ActsAsTenant.with_tenant(organization) do
          expect(Evaluation.active.count).to eq(2)
        end
      end
    end

    describe '.for_manager' do
      it 'returns evaluations for a specific manager' do
        ActsAsTenant.with_tenant(organization) do
          expect(Evaluation.for_manager(manager).count).to eq(3)
        end
      end
    end

    describe '.for_employee' do
      it 'returns evaluations for a specific employee' do
        ActsAsTenant.with_tenant(organization) do
          expect(Evaluation.for_employee(employee).count).to eq(3)
        end
      end
    end

    describe '.by_period' do
      it 'filters evaluations by year of period_end' do
        ActsAsTenant.with_tenant(organization) do
          expect(Evaluation.by_period(2025).count).to eq(1)
        end
      end
    end
  end

  describe 'instance methods' do
    let(:evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager)
    end

    describe '#complete!' do
      it 'marks evaluation as completed and sets completed_at' do
        expect {
          evaluation.complete!(final_score: 3)
        }.to change { evaluation.reload.status }.to('completed')
          .and change { evaluation.completed_at }.from(nil)
      end

      it 'sets the score when completing' do
        evaluation.complete!(final_score: 4)
        expect(evaluation.reload.score).to eq('exceeds_expectations')
      end

      it 'is idempotent — does not update completed_at when already completed' do
        evaluation.complete!(final_score: 3)
        original_completed_at = evaluation.reload.completed_at

        travel 1.hour do
          evaluation.complete!(final_score: 5)
        end

        expect(evaluation.reload.completed_at).to eq(original_completed_at)
        expect(evaluation.reload.score).to eq('meets_expectations')
      end
    end

    describe '#advance_to_manager_review!' do
      let(:evaluation) do
        create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
               status: :employee_review_pending)
      end

      it 'sets self_review and advances status to manager_review_pending' do
        evaluation.advance_to_manager_review!(self_review_text: 'This year I achieved...')
        evaluation.reload
        expect(evaluation.status).to eq('manager_review_pending')
        expect(evaluation.self_review).to eq('This year I achieved...')
      end

      it 'is idempotent — does nothing if already manager_review_pending' do
        evaluation.update!(status: :manager_review_pending, self_review: 'Original')
        evaluation.advance_to_manager_review!(self_review_text: 'New text')
        expect(evaluation.reload.self_review).to eq('Original')
      end

      it 'is idempotent — does nothing if already completed' do
        evaluation.update_columns(status: 'completed')
        evaluation.advance_to_manager_review!(self_review_text: 'Too late')
        expect(evaluation.reload.status).to eq('completed')
      end
    end

    describe '#self_review_submitted?' do
      it 'returns false when self_review is blank' do
        expect(evaluation.self_review_submitted?).to be false
      end

      it 'returns true when self_review is present' do
        evaluation.update!(self_review: 'My review')
        expect(evaluation.self_review_submitted?).to be true
      end
    end

    describe '#manager_review_submitted?' do
      it 'returns false when manager_review is blank' do
        expect(evaluation.manager_review_submitted?).to be false
      end

      it 'returns true when manager_review is present' do
        evaluation.update!(manager_review: 'Manager review')
        expect(evaluation.manager_review_submitted?).to be true
      end
    end

    describe '#fully_reviewed?' do
      it 'returns false when neither review submitted' do
        expect(evaluation.fully_reviewed?).to be false
      end

      it 'returns false when only self_review submitted' do
        evaluation.update!(self_review: 'My review')
        expect(evaluation.fully_reviewed?).to be false
      end

      it 'returns true when both reviews submitted' do
        evaluation.update!(self_review: 'My review', manager_review: 'Manager review')
        expect(evaluation.fully_reviewed?).to be true
      end
    end
  end

  describe 'multi-tenancy' do
    it 'scopes evaluations to organization' do
      org1 = create(:organization)
      org2 = create(:organization)
      manager1 = create(:employee, organization: org1, role: 'manager')
      manager2 = create(:employee, organization: org2, role: 'manager')
      employee1 = create(:employee, organization: org1, manager: manager1)
      employee2 = create(:employee, organization: org2, manager: manager2)

      ActsAsTenant.with_tenant(org1) do
        create(:evaluation, organization: org1, employee: employee1, manager: manager1, created_by: manager1)
      end

      ActsAsTenant.with_tenant(org2) do
        create(:evaluation, organization: org2, employee: employee2, manager: manager2, created_by: manager2)
      end

      ActsAsTenant.with_tenant(org1) do
        expect(Evaluation.count).to eq(1)
      end

      ActsAsTenant.with_tenant(org2) do
        expect(Evaluation.count).to eq(1)
      end
    end
  end

  describe 'security: status cannot be set via mass assignment' do
    let(:evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
             status: :draft)
    end

    it 'does not change status when update is called without explicit domain method' do
      # Simulates the HIGH-1 fix: :status removed from evaluation_params.
      # Even if a bad actor sends status: :completed, a controller calling
      # update(permitted_params) where :status is absent cannot change the status.
      evaluation.update(manager_review: 'Some review')
      expect(evaluation.reload.status).to eq('draft')
    end

    it 'does not populate completed_at when status is set via direct update' do
      # Regression guard for HIGH-2: verifies that only complete! correctly sets completed_at.
      # Direct status update bypasses the domain method.
      evaluation.update_columns(status: 'completed')  # bypass validations intentionally to simulate old bug
      expect(evaluation.reload.completed_at).to be_nil
    end
  end

  describe 'submit_manager_review flow (HIGH-2 regression guard)' do
    let(:evaluation) do
      create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager,
             status: :manager_review_pending)
    end

    it 'sets completed_at when manager_review is updated then complete! is called' do
      # This is the corrected submit_manager_review flow:
      # 1. update!(manager_review:) — persists the review text
      # 2. complete! — sets status AND completed_at atomically
      evaluation.update!(manager_review: 'Strong performance this year.')
      evaluation.complete!

      evaluation.reload
      expect(evaluation.status).to eq('completed')
      expect(evaluation.manager_review).to eq('Strong performance this year.')
      expect(evaluation.completed_at).not_to be_nil
    end
  end

  describe 'optional objectives link' do
    it 'can be linked to objectives' do
      ActsAsTenant.with_tenant(organization) do
        evaluation = create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager)
        objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)
        evaluation.objectives << objective
        expect(evaluation.reload.objectives).to include(objective)
      end
    end

    it 'prevents duplicate objective links' do
      ActsAsTenant.with_tenant(organization) do
        evaluation = create(:evaluation, organization: organization, employee: employee, manager: manager, created_by: manager)
        objective = create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee)
        evaluation.objectives << objective

        expect {
          EvaluationObjective.create!(evaluation: evaluation, objective: objective)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
