# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:admin)    { create(:employee, organization: organization, role: 'admin') }
  let(:hr)       { create(:employee, organization: organization, role: 'hr') }
  let(:manager)  { create(:employee, organization: organization, role: 'manager') }
  let(:employee) { create(:employee, organization: organization) }

  subject { described_class }

  permissions :index?, :time_entries?, :absences?, :search?, :search_export? do
    it 'permits admin' do
      expect(subject).to permit(admin, :exports)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, :exports)
    end

    it 'permits manager' do
      expect(subject).to permit(manager, :exports)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee, :exports)
    end
  end
end
