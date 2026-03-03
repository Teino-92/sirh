# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GroupPoliciesPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:admin)    { create(:employee, organization: organization, role: 'admin') }
  let(:hr)       { create(:employee, organization: organization, role: 'hr') }
  let(:manager)  { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization) }

  subject { described_class }

  permissions :edit?, :update?, :preview? do
    it 'permits admin' do
      expect(subject).to permit(admin, organization)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, organization)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, organization)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, organization)
    end
  end
end
