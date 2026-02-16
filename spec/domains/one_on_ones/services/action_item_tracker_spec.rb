require 'rails_helper'

RSpec.describe OneOnOnes::Services::ActionItemTracker do
  let(:organization) { create(:organization) }
  let(:manager) { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization, manager: manager) }
  let(:one_on_one) { create(:one_on_one, organization: organization, manager: manager, employee: employee) }
  let(:tracker) { described_class.new(employee) }

  describe '#my_action_items' do
    let!(:my_action_item) { create(:action_item, one_on_one: one_on_one, responsible: employee) }
    let!(:other_action_item) { create(:action_item, one_on_one: one_on_one, responsible: manager) }

    it 'returns action items for employee' do
      items = tracker.my_action_items
      expect(items).to include(my_action_item)
    end

    it 'filters by status when provided' do
      pending_item = create(:action_item, one_on_one: one_on_one, responsible: employee, status: :pending)
      in_progress_item = create(:action_item, one_on_one: one_on_one, responsible: employee, status: :in_progress)

      items = tracker.my_action_items(status: :pending)
      expect(items).to include(pending_item)
      expect(items).not_to include(in_progress_item)
    end
  end

  describe '#overdue_items' do
    let!(:overdue_item) do
      item = build(:action_item, one_on_one: one_on_one, responsible: employee, status: :pending, deadline: 1.week.ago)
      item.save(validate: false)
      item
    end
    let!(:future_item) { create(:action_item, one_on_one: one_on_one, responsible: employee, deadline: 1.week.from_now) }

    it 'returns only overdue action items' do
      items = tracker.overdue_items
      expect(items).to include(overdue_item)
      expect(items).not_to include(future_item)
    end
  end

  describe '#link_objective_as_action_item' do
    let(:objective) { create(:objective, organization: organization, manager: manager, created_by: manager, owner: employee) }

    it 'creates action item linked to objective' do
      action_item = tracker.link_objective_as_action_item(
        one_on_one: one_on_one,
        objective: objective,
        deadline: 2.weeks.from_now.to_date
      )

      expect(action_item).to be_persisted
      expect(action_item.objective).to eq(objective)
      expect(action_item.responsible).to eq(employee)
      expect(action_item.description).to include(objective.title)
    end
  end
end
