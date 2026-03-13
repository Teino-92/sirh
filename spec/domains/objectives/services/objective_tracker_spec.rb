require 'rails_helper'

RSpec.describe ObjectiveTracker do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:tracker) { described_class.new(organization) }

  describe '#team_progress_summary' do
    before do
      create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :in_progress)
      create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :blocked)
      create(:objective, :completed, organization: organization, manager: manager, created_by: manager, owner: employee)

      overdue = build(:objective, organization: organization, manager: manager, created_by: manager, owner: employee, status: :in_progress, deadline: 1.week.ago)
      overdue.save(validate: false)
    end

    it 'returns summary of team objectives' do
      summary = tracker.team_progress_summary(manager)

      expect(summary[:total]).to eq(3)
      expect(summary[:in_progress]).to eq(2)
      expect(summary[:blocked]).to eq(1)
      expect(summary[:overdue]).to eq(1)
    end
  end

  describe '#bulk_complete' do
    let!(:objective1) { create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee) }
    let!(:objective2) { create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee) }

    it 'completes multiple objectives' do
      count = tracker.bulk_complete([objective1.id, objective2.id], completed_by: manager)

      expect(count).to eq(2)
      expect(objective1.reload.status).to eq('completed')
      expect(objective2.reload.status).to eq('completed')
    end

    it 'uses transaction for atomicity' do
      allow_any_instance_of(Objective).to receive(:complete!).and_raise(ActiveRecord::RecordInvalid)

      expect {
        tracker.bulk_complete([objective1.id, objective2.id], completed_by: manager)
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(objective1.reload.status).not_to eq('completed')
      expect(objective2.reload.status).not_to eq('completed')
    end
  end
end
