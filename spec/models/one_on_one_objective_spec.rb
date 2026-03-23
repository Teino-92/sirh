# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OneOnOneObjective, type: :model do
  let(:org)      { create(:organization) }
  let(:manager)  { create(:employee, :manager, organization: org) }
  let(:employee) { create(:employee, organization: org) }

  let(:one_on_one) do
    ActsAsTenant.with_tenant(org) do
      create(:one_on_one, organization: org, manager: manager, employee: employee)
    end
  end

  let(:objective) do
    ActsAsTenant.with_tenant(org) do
      create(:objective, organization: org, manager: manager, owner: employee, created_by: manager)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:one_on_one) }
    it { is_expected.to belong_to(:objective) }
  end

  describe 'cross-tenant validation' do
    context 'when one_on_one and objective belong to the same organization' do
      it 'is valid' do
        ActsAsTenant.with_tenant(org) do
          record = OneOnOneObjective.new(one_on_one: one_on_one, objective: objective)
          expect(record).to be_valid
        end
      end
    end

    context 'when one_on_one and objective belong to different organizations' do
      let(:other_org)     { create(:organization) }
      let(:other_manager) { create(:employee, :manager, organization: other_org) }
      let(:other_emp)     { create(:employee, organization: other_org) }

      let(:other_objective) do
        ActsAsTenant.with_tenant(other_org) do
          create(:objective, organization: other_org, manager: other_manager,
                             owner: other_emp, created_by: other_manager)
        end
      end

      it 'is invalid' do
        ActsAsTenant.with_tenant(org) do
          record = OneOnOneObjective.new(one_on_one: one_on_one, objective: other_objective)
          expect(record).not_to be_valid
          expect(record.errors[:base]).to include(
            "Le 1:1 et l'objectif doivent appartenir à la même organisation"
          )
        end
      end

      it 'cannot be saved' do
        ActsAsTenant.with_tenant(org) do
          record = OneOnOneObjective.new(one_on_one: one_on_one, objective: other_objective)
          expect { record.save! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end
  end
end
