# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PayrollPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:admin)    { create(:employee, organization: organization, role: 'admin') }
  let(:hr)       { create(:employee, organization: organization, role: 'hr') }
  let(:manager)  { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization) }

  subject { described_class }

  permissions :show? do
    it 'permits admin' do
      expect(subject).to permit(admin, :payroll)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, :payroll)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, :payroll)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, :payroll)
    end
  end

  permissions :export? do
    it { is_expected.to     permit(admin,    :payroll) }
    it { is_expected.to     permit(hr,       :payroll) }
    it { is_expected.not_to permit(manager,  :payroll) }
    it { is_expected.not_to permit(employee, :payroll) }
  end

  permissions :export_silae? do
    it { is_expected.to     permit(admin,    :payroll) }
    it { is_expected.to     permit(hr,       :payroll) }
    it { is_expected.not_to permit(manager,  :payroll) }
    it { is_expected.not_to permit(employee, :payroll) }
  end
end
