# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveRequestPolicy, type: :policy do
  let(:organization) { create(:organization, plan: 'sirh') }
  let(:hr)           { create(:employee, organization: organization, role: 'hr') }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization, manager: manager) }
  let(:other)        { create(:employee, organization: organization) }

  let(:pending_request) do
    ActsAsTenant.with_tenant(organization) do
      create(:leave_request, :pending, employee: employee, organization: organization)
    end
  end

  let(:approved_request) do
    ActsAsTenant.with_tenant(organization) do
      create(:leave_request, :approved, employee: employee, organization: organization)
    end
  end

  subject { described_class }

  context 'on manager_os plan' do
    let(:organization) { create(:organization, plan: 'manager_os') }

    permissions :index?, :create?, :show?, :approve?, :reject? do
      it 'denies all actions (SIRH-only feature)' do
        expect(subject).not_to permit(hr, LeaveRequest.new)
      end
    end
  end

  context 'on sirh plan' do
    describe 'Scope' do
      let!(:employee_request) do
        ActsAsTenant.with_tenant(organization) { create(:leave_request, employee: employee, organization: organization) }
      end
      let!(:other_request) do
        ActsAsTenant.with_tenant(organization) { create(:leave_request, employee: other, organization: organization) }
      end

      context 'as HR' do
        it 'returns all leave requests' do
          resolved = LeaveRequestPolicy::Scope.new(hr, LeaveRequest).resolve
          expect(resolved).to include(employee_request, other_request)
        end
      end

      context 'as manager' do
        it 'returns own and team requests' do
          resolved = LeaveRequestPolicy::Scope.new(manager, LeaveRequest).resolve
          expect(resolved).to include(employee_request)
          expect(resolved).not_to include(other_request)
        end
      end

      context 'as plain employee' do
        it 'returns only own requests' do
          resolved = LeaveRequestPolicy::Scope.new(employee, LeaveRequest).resolve
          expect(resolved).to include(employee_request)
          expect(resolved).not_to include(other_request)
        end
      end
    end

    permissions :index? do
      it 'permits HR' do
        expect(subject).to permit(hr, LeaveRequest.new)
      end

      it 'permits manager' do
        expect(subject).to permit(manager, LeaveRequest.new)
      end

      it 'permits plain employee' do
        expect(subject).to permit(employee, LeaveRequest.new)
      end
    end

    permissions :show? do
      it 'permits owner to view their own request' do
        expect(subject).to permit(employee, pending_request)
      end

      it 'permits manager to view their report request' do
        expect(subject).to permit(manager, pending_request)
      end

      it 'permits HR to view any request' do
        expect(subject).to permit(hr, pending_request)
      end

      it 'denies other employee from viewing' do
        expect(subject).not_to permit(other, pending_request)
      end
    end

    permissions :create?, :new? do
      it 'permits any sirh user to create' do
        expect(subject).to permit(employee, LeaveRequest.new)
        expect(subject).to permit(manager, LeaveRequest.new)
        expect(subject).to permit(hr, LeaveRequest.new)
      end
    end

    permissions :update?, :edit? do
      it 'permits owner to update a pending request' do
        expect(subject).to permit(employee, pending_request)
      end

      it 'denies owner from updating an approved request' do
        expect(subject).not_to permit(employee, approved_request)
      end

      it 'denies manager from updating an employee request' do
        expect(subject).not_to permit(manager, pending_request)
      end

      it 'denies HR from updating an employee request' do
        expect(subject).not_to permit(hr, pending_request)
      end
    end

    permissions :destroy? do
      it 'denies everyone from destroying' do
        expect(subject).not_to permit(hr, pending_request)
        expect(subject).not_to permit(manager, pending_request)
        expect(subject).not_to permit(employee, pending_request)
      end
    end

    permissions :approve?, :reject? do
      it 'permits HR to approve/reject' do
        expect(subject).to permit(hr, pending_request)
      end

      it 'permits manager to approve/reject their report (when group policy allows)' do
        organization.settings['group_policies'] = { 'manager_can_approve_leave' => true }
        organization.save!
        expect(subject).to permit(manager, pending_request)
      end

      it 'denies manager when group policy disables manager approval' do
        organization.settings['group_policies'] = { 'manager_can_approve_leave' => false }
        organization.save!
        expect(subject).not_to permit(manager, pending_request)
      end

      it 'denies plain employee from approving' do
        expect(subject).not_to permit(employee, pending_request)
      end

      it 'denies manager from approving requests outside their team' do
        other_request = ActsAsTenant.with_tenant(organization) do
          create(:leave_request, :pending, employee: other, organization: organization)
        end
        expect(subject).not_to permit(manager, other_request)
      end
    end

    permissions :cancel? do
      it 'permits owner to cancel a pending request' do
        expect(subject).to permit(employee, pending_request)
      end

      it 'permits owner to cancel an approved request' do
        expect(subject).to permit(employee, approved_request)
      end

      it 'denies owner from canceling a rejected request' do
        rejected = ActsAsTenant.with_tenant(organization) do
          create(:leave_request, :rejected, employee: employee, organization: organization)
        end
        expect(subject).not_to permit(employee, rejected)
      end

      it 'denies manager from canceling' do
        expect(subject).not_to permit(manager, pending_request)
      end
    end
  end
end
