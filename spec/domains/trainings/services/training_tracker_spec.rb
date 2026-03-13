require 'rails_helper'

RSpec.describe TrainingTracker do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee1) { create(:employee, organization: organization, manager: manager) }
  let(:employee2) { create(:employee, organization: organization, manager: manager) }
  let(:employee3) { create(:employee, organization: organization, manager: manager) }
  let(:training) { create(:training, organization: organization) }
  let(:tracker) { described_class.new(organization) }

  describe '#employees_without_training' do
    context 'when some employees have recent completed training' do
      before do
        training2 = create(:training, organization: organization)
        ActsAsTenant.with_tenant(organization) do
          # employee1 has a completed training within 6 months
          create(:training_assignment, :completed,
            training: training,
            employee: employee1,
            assigned_by: manager,
            assigned_at: Date.current,
            completed_at: 1.month.ago
          )
          # employee2 has a completed training for a different training (needed to avoid unique constraint)
          create(:training_assignment, :completed,
            training: training2,
            employee: employee2,
            assigned_by: manager,
            assigned_at: Date.current,
            completed_at: 8.months.ago  # outside 6-month window
          )
          # employee3 has no training at all
        end
      end

      it 'returns employees without training in the last 6 months' do
        result = tracker.employees_without_training(months: 6)
        # employee1 has recent training, employee2's was 8 months ago, employee3 has none
        expect(result).to include(employee2, employee3)
        expect(result).not_to include(employee1)
      end

      it 'includes the manager who also has no recent training' do
        result = tracker.employees_without_training(months: 6)
        expect(result).to include(manager)
      end
    end

    context 'when all employees have recent completed training' do
      before do
        training2 = create(:training, organization: organization)
        training3 = create(:training, organization: organization)
        ActsAsTenant.with_tenant(organization) do
          [employee1, employee2, employee3].each_with_index do |emp, i|
            t = [training, training2, training3][i]
            create(:training_assignment, :completed,
              training: t, employee: emp, assigned_by: manager,
              assigned_at: Date.current, completed_at: 1.month.ago
            )
          end
        end
      end

      it 'returns only employees without recent training (manager in this case)' do
        result = tracker.employees_without_training(months: 6)
        expect(result).not_to include(employee1, employee2, employee3)
        expect(result).to include(manager)
      end
    end
  end

  describe '#bulk_assign' do
    it 'creates assignments for all provided employee IDs' do
      expect {
        tracker.bulk_assign(
          training: training,
          employee_ids: [employee1.id, employee2.id],
          assigned_by: manager
        )
      }.to change(TrainingAssignment, :count).by(2)
    end

    it 'sets deadline when provided' do
      deadline = 1.month.from_now.to_date
      tracker.bulk_assign(
        training: training,
        employee_ids: [employee1.id],
        assigned_by: manager,
        deadline: deadline
      )

      expect(TrainingAssignment.last.deadline).to eq(deadline)
    end

    it 'is transactional — rolls back all on failure' do
      invalid_employee_id = -1

      expect {
        tracker.bulk_assign(
          training: training,
          employee_ids: [employee1.id, invalid_employee_id],
          assigned_by: manager
        )
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(TrainingAssignment.count).to eq(0)
    end

    it 'returns the created assignments' do
      assignments = tracker.bulk_assign(
        training: training,
        employee_ids: [employee1.id, employee2.id],
        assigned_by: manager
      )

      expect(assignments.length).to eq(2)
      expect(assignments.map(&:employee_id)).to contain_exactly(employee1.id, employee2.id)
    end
  end

  describe '#completion_summary' do
    before do
      training2 = create(:training, organization: organization)
      ActsAsTenant.with_tenant(organization) do
        create(:training_assignment, :completed,
          training: training, employee: employee1, assigned_by: manager,
          assigned_at: Date.current, completed_at: Time.new(2025, 6, 1)
        )
        create(:training_assignment, :completed,
          training: training2, employee: employee2, assigned_by: manager,
          assigned_at: Date.current, completed_at: Time.new(2025, 9, 1)
        )
        # employee3 and manager have no training in 2025
      end
    end

    it 'returns trained count for the given year' do
      result = tracker.completion_summary(year: 2025)
      expect(result[:trained]).to eq(2)
    end

    it 'returns 0 trained for a year with no completions' do
      result = tracker.completion_summary(year: 2020)
      expect(result[:trained]).to eq(0)
      expect(result[:rate]).to eq(0)
    end

    it 'returns total active employee count' do
      result = tracker.completion_summary(year: 2025)
      # organization has at least manager + employee1 + employee2 (employee3 is lazy-instantiated)
      expect(result[:total]).to be >= 3
      expect(result[:total]).to be > 0
    end

    it 'calculates untrained as total minus trained' do
      result = tracker.completion_summary(year: 2025)
      expect(result[:untrained]).to eq(result[:total] - result[:trained])
    end
  end
end
