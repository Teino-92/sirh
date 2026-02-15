# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LeaveRequest, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:employee, organization: organization) }
  let!(:leave_balance) { create(:leave_balance, :full_balance, employee: employee, leave_type: 'CP') }
  let(:leave_request) { build(:leave_request, employee: employee, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:employee) }
    it { is_expected.to belong_to(:approved_by).class_name('Employee').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:leave_type) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
    it { is_expected.to validate_presence_of(:days_count) }
    it { is_expected.to validate_presence_of(:status) }

    it do
      is_expected.to validate_inclusion_of(:leave_type)
        .in_array(LeaveBalance::LEAVE_TYPES.keys)
    end

    it do
      is_expected.to validate_inclusion_of(:status)
        .in_array(%w[pending approved rejected cancelled auto_approved])
    end

    context 'with valid attributes' do
      it 'is valid' do
        ActsAsTenant.with_tenant(organization) do
          expect(leave_request).to be_valid
        end
      end
    end

    describe 'end_date_after_start_date validation' do
      it 'is invalid when end_date is before start_date' do
        ActsAsTenant.with_tenant(organization) do
          leave_request.start_date = Date.current + 7
          leave_request.end_date = Date.current + 5
          expect(leave_request).not_to be_valid
          expect(leave_request.errors[:end_date]).to include('must be after start date')
        end
      end

      it 'is valid when end_date equals start_date (single day leave)' do
        ActsAsTenant.with_tenant(organization) do
          leave_request.start_date = Date.current + 7
          leave_request.end_date = Date.current + 7
          leave_request.days_count = 1
          expect(leave_request).to be_valid
        end
      end

      it 'is valid when end_date is after start_date' do
        ActsAsTenant.with_tenant(organization) do
          leave_request.start_date = Date.current + 7
          leave_request.end_date = Date.current + 14
          expect(leave_request).to be_valid
        end
      end
    end

    describe 'sufficient_balance validation' do
      it 'is invalid when requesting more days than available balance' do
        ActsAsTenant.with_tenant(organization) do
          # Update existing balance to low
          leave_balance.update!(balance: 2.5, accrued_this_year: 10.0, used_this_year: 7.5)
          leave_request.leave_type = 'CP'
          leave_request.days_count = 10.0
          expect(leave_request).not_to be_valid
          expect(leave_request.errors[:base]).to include(/Insufficient CP balance/)
        end
      end

      it 'is valid when requesting days within available balance' do
        ActsAsTenant.with_tenant(organization) do
          leave_request.leave_type = 'CP'
          leave_request.days_count = 5.0
          expect(leave_request).to be_valid
        end
      end

      it 'checks balance for the correct leave type' do
        ActsAsTenant.with_tenant(organization) do
          rtt_balance = create(:leave_balance, :rtt, employee: employee, balance: 3.0)
          leave_request.leave_type = 'RTT'
          leave_request.days_count = 2.0
          expect(leave_request).to be_valid
        end
      end
    end

    describe 'employee_belongs_to_same_organization validation' do
      it 'is invalid when employee belongs to different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)

        ActsAsTenant.with_tenant(organization) do
          leave_request.employee = other_employee
          expect(leave_request).not_to be_valid
          expect(leave_request.errors[:employee]).to include('must belong to the same organization')
        end
      end
    end

    describe 'approver_belongs_to_same_organization validation' do
      it 'is invalid when approver belongs to different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, :manager, organization: other_org)

        ActsAsTenant.with_tenant(organization) do
          leave_request.approved_by = other_manager
          expect(leave_request).not_to be_valid
          expect(leave_request.errors[:approved_by]).to include('must belong to the same organization')
        end
      end

      it 'is valid when approver belongs to same organization' do
        manager = create(:employee, :manager, organization: organization)

        ActsAsTenant.with_tenant(organization) do
          leave_request.approved_by = manager
          expect(leave_request).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let!(:pending_request) { create(:leave_request, :pending, employee: employee, organization: organization) }
    let!(:approved_request) { create(:leave_request, :approved, employee: employee, organization: organization) }
    let!(:auto_approved_request) { create(:leave_request, :auto_approved, employee: employee, organization: organization) }
    let!(:rejected_request) { create(:leave_request, :rejected, employee: employee, organization: organization) }

    describe '.pending' do
      it 'returns only pending requests' do
        ActsAsTenant.with_tenant(organization) do
          expect(LeaveRequest.pending).to include(pending_request)
          expect(LeaveRequest.pending).not_to include(approved_request, rejected_request)
        end
      end
    end

    describe '.approved' do
      it 'returns approved and auto_approved requests' do
        ActsAsTenant.with_tenant(organization) do
          approved_requests = LeaveRequest.approved
          expect(approved_requests).to include(approved_request, auto_approved_request)
          expect(approved_requests).not_to include(pending_request, rejected_request)
        end
      end
    end

    describe '.rejected' do
      it 'returns only rejected requests' do
        ActsAsTenant.with_tenant(organization) do
          expect(LeaveRequest.rejected).to include(rejected_request)
          expect(LeaveRequest.rejected).not_to include(pending_request, approved_request)
        end
      end
    end

    describe '.for_date_range' do
      let!(:request_in_range) do
        create(:leave_request,
               employee: employee,
               organization: organization,
               start_date: Date.current + 10,
               end_date: Date.current + 15)
      end
      let!(:request_out_of_range) do
        create(:leave_request,
               employee: employee,
               organization: organization,
               start_date: Date.current + 30,
               end_date: Date.current + 35)
      end

      it 'returns requests overlapping with date range' do
        ActsAsTenant.with_tenant(organization) do
          results = LeaveRequest.for_date_range(Date.current + 12, Date.current + 20)
          expect(results).to include(request_in_range)
          expect(results).not_to include(request_out_of_range)
        end
      end

      it 'includes requests that partially overlap' do
        ActsAsTenant.with_tenant(organization) do
          results = LeaveRequest.for_date_range(Date.current + 14, Date.current + 20)
          expect(results).to include(request_in_range)
        end
      end
    end

    describe '.for_employee' do
      let(:other_employee) { create(:employee, organization: organization) }
      let!(:other_request) { create(:leave_request, employee: other_employee, organization: organization) }

      it 'returns requests for specific employee' do
        ActsAsTenant.with_tenant(organization) do
          results = LeaveRequest.for_employee(employee.id)
          expect(results).to include(pending_request)
          expect(results).not_to include(other_request)
        end
      end
    end

    describe '.for_team' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let(:team_member1) { create(:employee, organization: organization, manager: manager) }
      let(:team_member2) { create(:employee, organization: organization, manager: manager) }
      let(:other_employee) { create(:employee, organization: organization) }

      let!(:team_request1) { create(:leave_request, employee: team_member1, organization: organization) }
      let!(:team_request2) { create(:leave_request, employee: team_member2, organization: organization) }
      let!(:other_request) { create(:leave_request, employee: other_employee, organization: organization) }

      it 'returns requests for manager team members only' do
        ActsAsTenant.with_tenant(organization) do
          results = LeaveRequest.for_team(manager)
          expect(results).to include(team_request1, team_request2)
          expect(results).not_to include(other_request)
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create :notify_manager' do
      it 'is called after creating a leave request' do
        ActsAsTenant.with_tenant(organization) do
          expect(leave_request).to receive(:notify_manager)
          leave_request.save
        end
      end
    end

    describe 'after_update :update_leave_balance' do
      it 'updates balance when status changes to approved' do
        ActsAsTenant.with_tenant(organization) do
          request = create(:leave_request, :pending, employee: employee, organization: organization, days_count: 5.0)
          initial_balance = leave_balance.reload.balance

          request.update!(status: 'approved')

          expect(leave_balance.reload.balance).to eq(initial_balance - 5.0)
          expect(leave_balance.used_this_year).to eq(5.0)
        end
      end

      it 'does not update balance when status changes to rejected' do
        ActsAsTenant.with_tenant(organization) do
          request = create(:leave_request, :pending, employee: employee, organization: organization)
          initial_balance = leave_balance.reload.balance

          request.update!(status: 'rejected')

          expect(leave_balance.reload.balance).to eq(initial_balance)
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#approve!' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let(:request) { create(:leave_request, :pending, employee: employee, organization: organization) }

      it 'updates status to approved' do
        ActsAsTenant.with_tenant(organization) do
          request.approve!(manager)
          expect(request.status).to eq('approved')
        end
      end

      it 'sets approved_by' do
        ActsAsTenant.with_tenant(organization) do
          request.approve!(manager)
          expect(request.approved_by).to eq(manager)
        end
      end

      it 'sets approved_at timestamp' do
        ActsAsTenant.with_tenant(organization) do
          freeze_time do
            request.approve!(manager)
            expect(request.approved_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      context 'transaction atomicity' do
        it 'rolls back leave request status if balance update fails' do
          ActsAsTenant.with_tenant(organization) do
            balance = employee.leave_balances.find_by(leave_type: request.leave_type)
            allow(balance).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
            allow(employee.leave_balances).to receive(:find_by).and_return(balance)

            expect {
              request.approve!(manager)
            }.to raise_error(ActiveRecord::RecordInvalid)

            expect(request.reload.status).to eq('pending')
          end
        end

        it 'commits both leave request and balance updates together' do
          ActsAsTenant.with_tenant(organization) do
            balance = employee.leave_balances.find_by(leave_type: request.leave_type)
            initial_balance = balance.balance

            request.approve!(manager)

            expect(request.reload.status).to eq('approved')
            expect(balance.reload.balance).to eq(initial_balance - request.days_count)
          end
        end
      end
    end

    describe '#reject!' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let(:request) { create(:leave_request, :pending, employee: employee, organization: organization) }

      it 'updates status to rejected' do
        ActsAsTenant.with_tenant(organization) do
          request.reject!(manager, reason: 'Coverage issue')
          expect(request.status).to eq('rejected')
        end
      end

      it 'sets approved_by' do
        ActsAsTenant.with_tenant(organization) do
          request.reject!(manager, reason: 'Coverage issue')
          expect(request.approved_by).to eq(manager)
        end
      end

      it 'sets rejection_reason' do
        ActsAsTenant.with_tenant(organization) do
          request.reject!(manager, reason: 'Team coverage issue')
          expect(request.rejection_reason).to eq('Team coverage issue')
        end
      end

      it 'sets approved_at timestamp' do
        ActsAsTenant.with_tenant(organization) do
          freeze_time do
            request.reject!(manager, reason: 'Coverage issue')
            expect(request.approved_at).to be_within(1.second).of(Time.current)
          end
        end
      end
    end

    describe '#auto_approve!' do
      let(:request) { create(:leave_request, :pending, employee: employee, organization: organization) }

      it 'updates status to auto_approved' do
        ActsAsTenant.with_tenant(organization) do
          request.auto_approve!
          expect(request.status).to eq('auto_approved')
        end
      end

      it 'sets approved_at timestamp' do
        ActsAsTenant.with_tenant(organization) do
          freeze_time do
            request.auto_approve!
            expect(request.approved_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      it 'does not set approved_by' do
        ActsAsTenant.with_tenant(organization) do
          request.auto_approve!
          expect(request.approved_by).to be_nil
        end
      end
    end

    describe '#approved?' do
      it 'returns true for approved status' do
        leave_request.status = 'approved'
        expect(leave_request.approved?).to be true
      end

      it 'returns true for auto_approved status' do
        leave_request.status = 'auto_approved'
        expect(leave_request.approved?).to be true
      end

      it 'returns false for pending status' do
        leave_request.status = 'pending'
        expect(leave_request.approved?).to be false
      end

      it 'returns false for rejected status' do
        leave_request.status = 'rejected'
        expect(leave_request.approved?).to be false
      end
    end

    describe '#pending?' do
      it 'returns true for pending status' do
        leave_request.status = 'pending'
        expect(leave_request.pending?).to be true
      end

      it 'returns false for approved status' do
        leave_request.status = 'approved'
        expect(leave_request.pending?).to be false
      end
    end

    describe '#conflicts_with_team?' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let(:team_member1) { create(:employee, organization: organization, manager: manager) }
      let(:team_member2) { create(:employee, organization: organization, manager: manager) }

      let(:request1) do
        create(:leave_request,
               employee: team_member1,
               organization: organization,
               start_date: Date.current + 10,
               end_date: Date.current + 15,
               status: 'approved')
      end

      context 'when another team member has overlapping approved leave' do
        it 'returns true' do
          ActsAsTenant.with_tenant(organization) do
            request2 = build(:leave_request,
                            employee: team_member2,
                            organization: organization,
                            start_date: Date.current + 12,
                            end_date: Date.current + 17)

            request1 # Create first request
            expect(request2.conflicts_with_team?).to be true
          end
        end
      end

      context 'when no team members have overlapping leave' do
        it 'returns false' do
          ActsAsTenant.with_tenant(organization) do
            request2 = build(:leave_request,
                            employee: team_member2,
                            organization: organization,
                            start_date: Date.current + 20,
                            end_date: Date.current + 25)

            request1 # Create first request
            expect(request2.conflicts_with_team?).to be false
          end
        end
      end

      context 'when employee has no manager' do
        it 'returns false' do
          ActsAsTenant.with_tenant(organization) do
            solo_employee = create(:employee, organization: organization, manager: nil)
            request = build(:leave_request, employee: solo_employee, organization: organization)

            expect(request.conflicts_with_team?).to be false
          end
        end
      end
    end
  end

  describe 'multi-tenancy' do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let(:emp1) { create(:employee, organization: org1) }
    let(:emp2) { create(:employee, organization: org2) }
    let!(:balance1) { create(:leave_balance, employee: emp1, organization: org1) }
    let!(:balance2) { create(:leave_balance, employee: emp2, organization: org2) }
    let!(:request1) { create(:leave_request, employee: emp1, organization: org1) }
    let!(:request2) { create(:leave_request, employee: emp2, organization: org2) }

    it 'scopes queries to current organization' do
      ActsAsTenant.with_tenant(org1) do
        expect(LeaveRequest.all).to include(request1)
        expect(LeaveRequest.all).not_to include(request2)
      end
    end
  end

  describe 'French leave types' do
    it 'accepts CP leave type' do
      leave_request.leave_type = 'CP'
      expect(leave_request).to be_valid
    end

    it 'accepts RTT leave type' do
      create(:leave_balance, :rtt, employee: employee, organization: organization)
      leave_request.leave_type = 'RTT'
      expect(leave_request).to be_valid
    end

    it 'accepts Maladie leave type' do
      create(:leave_balance, employee: employee, organization: organization, leave_type: 'Maladie')
      leave_request.leave_type = 'Maladie'
      expect(leave_request).to be_valid
    end

    it 'rejects invalid leave type' do
      leave_request.leave_type = 'InvalidType'
      expect(leave_request).not_to be_valid
    end
  end
end
