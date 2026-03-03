# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PayrollPeriodPolicy, type: :policy do
  let(:org)      { create(:organization) }
  let(:hr)       { create(:employee, organization: org, role: 'hr') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:manager)  { create(:employee, organization: org, role: 'manager') }
  let(:employee) { create(:employee, organization: org, role: 'employee') }
  let(:record)   { create(:payroll_period, organization: org, locked_by: hr) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  subject { described_class }

  permissions :index?, :create?, :destroy? do
    it 'permits hr' do
      expect(subject).to permit(hr, record)
    end

    it 'permits admin' do
      expect(subject).to permit(admin, record)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, record)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, record)
    end
  end
end
