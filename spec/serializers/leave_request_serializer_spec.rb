# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveRequestSerializer do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org) }
  let(:approver) { create(:employee, organization: org, role: 'manager') }
  let(:request)  { create(:leave_request, employee: employee, status: 'pending') }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  describe '#as_json' do
    subject(:data) { described_class.new(request).as_json }

    it 'includes core fields' do
      expect(data).to include(
        id:          request.id,
        leave_type:  request.leave_type,
        start_date:  request.start_date,
        end_date:    request.end_date,
        days_count:  request.days_count,
        status:      request.status
      )
    end

    it 'does not include employee by default' do
      expect(data).not_to have_key(:employee)
    end

    it 'does not include approved_by when nil' do
      expect(data).not_to have_key(:approved_by)
    end

    context 'with include_employee: true' do
      subject(:data) { described_class.new(request, include_employee: true).as_json }

      it 'includes employee sub-hash' do
        expect(data[:employee]).to include(
          id:        employee.id,
          full_name: employee.full_name
        )
      end
    end

    context 'when approved_by is set' do
      before do
        create(:leave_balance, :cp, employee: employee, balance: 20.0)
        request.update!(approved_by: approver, status: 'approved', approved_at: Time.current)
      end

      it 'includes approved_by sub-hash' do
        expect(data[:approved_by]).to include(
          id:        approver.id,
          full_name: approver.full_name
        )
      end
    end
  end
end
