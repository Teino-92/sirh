# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLogPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:admin)    { create(:employee, organization: organization, role: 'admin') }
  let(:hr)       { create(:employee, organization: organization, role: 'hr') }
  let(:manager)  { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization) }

  subject { described_class }

  permissions :show? do
    it 'permits admin' do
      expect(subject).to permit(admin, :audit_log)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, :audit_log)
    end

    it 'denies manager' do
      expect(subject).not_to permit(manager, :audit_log)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, :audit_log)
    end
  end
end
