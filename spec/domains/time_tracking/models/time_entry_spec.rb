# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TimeEntry, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:employee, organization: organization) }
  let(:time_entry) { build(:time_entry, employee: employee, organization: organization) }

  subject { time_entry }

  describe 'associations' do
    it 'belongs to employee' do
      expect(time_entry.employee).to eq(employee)
    end

    it 'belongs to validated_by optionally' do
      ActsAsTenant.with_tenant(organization) do
        manager = create(:employee, :manager, organization: organization)
        time_entry.validated_by = manager
        expect(time_entry.validated_by).to eq(manager)
      end
    end

    it 'belongs to rejected_by optionally' do
      ActsAsTenant.with_tenant(organization) do
        manager = create(:employee, :manager, organization: organization)
        time_entry.rejected_by = manager
        expect(time_entry.rejected_by).to eq(manager)
      end
    end
  end

  describe 'validations' do
    it 'requires clock_in' do
      ActsAsTenant.with_tenant(organization) do
        time_entry.clock_in = nil
        time_entry.clock_out = nil # Avoid comparison error
        expect(time_entry).not_to be_valid
        expect(time_entry.errors[:clock_in]).to be_present
      end
    end

    context 'with valid attributes' do
      it 'is valid' do
        ActsAsTenant.with_tenant(organization) do
          expect(time_entry).to be_valid
        end
      end
    end

    describe 'clock_out_after_clock_in validation' do
      it 'is invalid when clock_out is before clock_in' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current
          time_entry.clock_out = Time.current - 1.hour
          expect(time_entry).not_to be_valid
          expect(time_entry.errors[:clock_out]).to include('must be after clock in time')
        end
      end

      it 'is invalid when clock_out equals clock_in' do
        ActsAsTenant.with_tenant(organization) do
          time = Time.current
          time_entry.clock_in = time
          time_entry.clock_out = time
          expect(time_entry).not_to be_valid
          expect(time_entry.errors[:clock_out]).to include('must be after clock in time')
        end
      end

      it 'is valid when clock_out is after clock_in' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current - 2.hours
          time_entry.clock_out = Time.current
          expect(time_entry).to be_valid
        end
      end

      it 'is valid when clock_out is nil (active entry)' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current
          time_entry.clock_out = nil
          expect(time_entry).to be_valid
        end
      end
    end

    describe 'no_overlapping_entries validation' do
      let!(:existing_entry) do
        create(:time_entry,
               employee: employee,
               organization: organization,
               clock_in: Time.current - 3.hours,
               clock_out: Time.current - 1.hour)
      end

      it 'is invalid when overlapping with existing entry' do
        ActsAsTenant.with_tenant(organization) do
          overlapping_entry = build(:time_entry,
                                   employee: employee,
                                   organization: organization,
                                   clock_in: Time.current - 2.hours,
                                   clock_out: Time.current)
          expect(overlapping_entry).not_to be_valid
          expect(overlapping_entry.errors[:base]).to include('Overlapping time entry detected')
        end
      end

      it 'is valid when not overlapping with existing entry' do
        ActsAsTenant.with_tenant(organization) do
          non_overlapping_entry = build(:time_entry,
                                       employee: employee,
                                       organization: organization,
                                       clock_in: Time.current,
                                       clock_out: Time.current + 2.hours)
          expect(non_overlapping_entry).to be_valid
        end
      end

      it 'is invalid when starting during existing active entry' do
        ActsAsTenant.with_tenant(organization) do
          create(:time_entry, :active, employee: employee, organization: organization, clock_in: Time.current - 1.hour)

          new_entry = build(:time_entry,
                           employee: employee,
                           organization: organization,
                           clock_in: Time.current,
                           clock_out: Time.current + 1.hour)
          expect(new_entry).not_to be_valid
        end
      end

      it 'allows different employees to have overlapping entries' do
        ActsAsTenant.with_tenant(organization) do
          other_employee = create(:employee, organization: organization)
          overlapping_entry = build(:time_entry,
                                   employee: other_employee,
                                   organization: organization,
                                   clock_in: Time.current - 2.hours,
                                   clock_out: Time.current)
          expect(overlapping_entry).to be_valid
        end
      end
    end

    describe 'max_daily_hours validation (French legal limit)' do
      it 'is invalid when exceeding 10 hours' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current.change(hour: 8, min: 0)
          time_entry.clock_out = Time.current.change(hour: 19, min: 0) # 11 hours
          # The before_save callback will calculate duration_minutes
          time_entry.send(:calculate_duration)
          expect(time_entry).not_to be_valid
          expect(time_entry.errors[:base]).to include('Cannot exceed 10 hours per day (French legal limit)')
        end
      end

      it 'is valid when at exactly 10 hours' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current.change(hour: 8, min: 0)
          time_entry.clock_out = Time.current.change(hour: 18, min: 0) # 10 hours
          expect(time_entry).to be_valid
        end
      end

      it 'is valid when under 10 hours' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current.change(hour: 9, min: 0)
          time_entry.clock_out = Time.current.change(hour: 17, min: 0) # 8 hours
          expect(time_entry).to be_valid
        end
      end

      it 'does not validate when clock_out is nil' do
        ActsAsTenant.with_tenant(organization) do
          time_entry.clock_in = Time.current - 11.hours
          time_entry.clock_out = nil
          expect(time_entry).to be_valid
        end
      end
    end

    describe 'employee_belongs_to_same_organization validation' do
      it 'is invalid when employee belongs to different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)

        ActsAsTenant.with_tenant(organization) do
          time_entry.employee = other_employee
          expect(time_entry).not_to be_valid
          expect(time_entry.errors[:employee]).to include('must belong to the same organization')
        end
      end
    end

    describe 'validators_belong_to_same_organization validation' do
      it 'is invalid when validated_by belongs to different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, :manager, organization: other_org)

        ActsAsTenant.with_tenant(organization) do
          time_entry.validated_by = other_manager
          expect(time_entry).not_to be_valid
          expect(time_entry.errors[:validated_by]).to include('must belong to the same organization')
        end
      end

      it 'is invalid when rejected_by belongs to different organization' do
        other_org = create(:organization)
        other_manager = create(:employee, :manager, organization: other_org)

        ActsAsTenant.with_tenant(organization) do
          time_entry.rejected_by = other_manager
          expect(time_entry).not_to be_valid
          expect(time_entry.errors[:rejected_by]).to include('must belong to the same organization')
        end
      end
    end
  end

  describe 'scopes' do
    let!(:active_entry) do
      create(:time_entry, :active,
             employee: employee,
             organization: organization,
             clock_in: Time.current - 1.hour)
    end
    let!(:completed_entry) do
      create(:time_entry,
             employee: employee,
             organization: organization,
             clock_in: Time.current - 5.hours,
             clock_out: Time.current - 4.hours)
    end
    let!(:validated_entry) do
      create(:time_entry, :validated,
             employee: employee,
             organization: organization,
             clock_in: Time.current - 8.hours,
             clock_out: Time.current - 7.hours)
    end
    let!(:rejected_entry) do
      create(:time_entry, :rejected,
             employee: employee,
             organization: organization,
             clock_in: Time.current - 11.hours,
             clock_out: Time.current - 10.hours)
    end

    describe '.for_employee' do
      let(:other_employee) { create(:employee, organization: organization) }
      let!(:other_entry) { create(:time_entry, employee: other_employee, organization: organization) }

      it 'returns entries for specific employee' do
        ActsAsTenant.with_tenant(organization) do
          results = TimeEntry.for_employee(employee.id)
          expect(results).to include(active_entry, completed_entry)
          expect(results).not_to include(other_entry)
        end
      end
    end

    describe '.for_date' do
      let(:fresh_employee) { create(:employee, organization: organization) }

      let!(:today_entry) do
        create(:time_entry,
               employee: fresh_employee,
               organization: organization,
               clock_in: Time.current.change(hour: 14, min: 0),
               clock_out: Time.current.change(hour: 15, min: 0))
      end
      let!(:yesterday_entry) do
        create(:time_entry,
               employee: fresh_employee,
               organization: organization,
               clock_in: 1.day.ago.change(hour: 14, min: 0),
               clock_out: 1.day.ago.change(hour: 15, min: 0))
      end

      it 'returns entries for specific date' do
        ActsAsTenant.with_tenant(organization) do
          results = TimeEntry.for_employee(fresh_employee.id).for_date(Date.current)
          expect(results).to include(today_entry)
          expect(results).not_to include(yesterday_entry)
        end
      end
    end

    describe '.for_date_range' do
      let!(:entry_in_range) do
        create(:time_entry,
               employee: employee,
               organization: organization,
               clock_in: 3.days.ago.change(hour: 14, min: 0),
               clock_out: 3.days.ago.change(hour: 15, min: 0))
      end
      let!(:entry_out_of_range) do
        create(:time_entry,
               employee: employee,
               organization: organization,
               clock_in: 10.days.ago.change(hour: 14, min: 0),
               clock_out: 10.days.ago.change(hour: 15, min: 0))
      end

      it 'returns entries within date range' do
        ActsAsTenant.with_tenant(organization) do
          results = TimeEntry.for_date_range(7.days.ago.to_date, Date.current)
          expect(results).to include(entry_in_range)
          expect(results).not_to include(entry_out_of_range)
        end
      end
    end

    describe '.active' do
      it 'returns only active entries (clock_out is nil)' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.active).to include(active_entry)
          expect(TimeEntry.active).not_to include(completed_entry)
        end
      end
    end

    describe '.completed' do
      it 'returns only completed entries (clock_out is present)' do
        ActsAsTenant.with_tenant(organization) do
          results = TimeEntry.completed
          expect(results).to include(completed_entry, validated_entry, rejected_entry)
          expect(results).not_to include(active_entry)
        end
      end
    end

    describe '.this_week' do
      let(:scope_employee) { create(:employee, organization: organization) }
      let!(:this_week_entry) { create(:time_entry, :this_week, employee: scope_employee, organization: organization) }
      let!(:last_week_entry) { create(:time_entry, :last_week, employee: scope_employee, organization: organization) }

      it 'returns entries from current week' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.this_week).to include(this_week_entry)
          expect(TimeEntry.this_week).not_to include(last_week_entry)
        end
      end
    end

    describe '.this_month' do
      let!(:this_month_entry) do
        create(:time_entry,
               employee: employee,
               organization: organization,
               clock_in: Date.current.beginning_of_month.to_time + 14.hours,
               clock_out: Date.current.beginning_of_month.to_time + 15.hours)
      end
      let!(:last_month_entry) do
        create(:time_entry,
               employee: employee,
               organization: organization,
               clock_in: 1.month.ago.beginning_of_month.to_time + 14.hours,
               clock_out: 1.month.ago.beginning_of_month.to_time + 15.hours)
      end

      it 'returns entries from current month' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.this_month).to include(this_month_entry)
          expect(TimeEntry.this_month).not_to include(last_month_entry)
        end
      end
    end

    describe '.validated' do
      it 'returns only validated entries' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.validated).to include(validated_entry)
          expect(TimeEntry.validated).not_to include(completed_entry, rejected_entry)
        end
      end
    end

    describe '.rejected' do
      it 'returns only rejected entries' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.rejected).to include(rejected_entry)
          expect(TimeEntry.rejected).not_to include(completed_entry, validated_entry)
        end
      end
    end

    describe '.pending_validation' do
      it 'returns completed entries not yet validated or rejected' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.pending_validation).to include(completed_entry)
          expect(TimeEntry.pending_validation).not_to include(active_entry, validated_entry, rejected_entry)
        end
      end
    end

    describe '.validated_this_week' do
      let(:validated_employee) { create(:employee, organization: organization) }
      let!(:validated_this_week) do
        create(:time_entry,
               employee: validated_employee,
               organization: organization,
               clock_in: Date.current.beginning_of_week.to_time + 2.days + 14.hours,
               clock_out: Date.current.beginning_of_week.to_time + 2.days + 15.hours,
               validated_at: Date.current.beginning_of_week + 1.day,
               validated_by: create(:employee, :manager, organization: organization))
      end
      let!(:validated_last_week) do
        create(:time_entry,
               employee: validated_employee,
               organization: organization,
               clock_in: 1.week.ago.beginning_of_week.to_time + 2.days + 14.hours,
               clock_out: 1.week.ago.beginning_of_week.to_time + 2.days + 15.hours,
               validated_at: 1.week.ago.beginning_of_week + 1.day,
               validated_by: create(:employee, :manager, organization: organization))
      end

      it 'returns entries validated this week' do
        ActsAsTenant.with_tenant(organization) do
          expect(TimeEntry.validated_this_week).to include(validated_this_week)
          expect(TimeEntry.validated_this_week).not_to include(validated_last_week)
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save :calculate_duration' do
      it 'calculates duration_minutes when clock_out is set' do
        ActsAsTenant.with_tenant(organization) do
          entry = build(:time_entry,
                       employee: employee,
                       organization: organization,
                       clock_in: Time.current - 2.hours,
                       clock_out: Time.current)
          entry.save
          expect(entry.duration_minutes).to eq(120)
        end
      end

      it 'does not calculate duration when clock_out is nil' do
        ActsAsTenant.with_tenant(organization) do
          entry = build(:time_entry, :active, employee: employee, organization: organization, duration_minutes: 0)
          entry.save
          expect(entry.duration_minutes).to eq(0)
        end
      end
    end

    describe 'after_save :check_rtt_accrual' do
      it 'triggers RTT accrual calculation when clock_out is set', skip: 'RTT service disabled due to autoload issue' do
        ActsAsTenant.with_tenant(organization) do
          entry = create(:time_entry, :active, employee: employee, organization: organization)
          expect_any_instance_of(RttAccrualService).to receive(:calculate_and_accrue_weekly)

          entry.clock_out!(time: Time.current)
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#clock_out!' do
      let(:entry) { create(:time_entry, :active, employee: employee, organization: organization) }

      it 'sets clock_out time' do
        ActsAsTenant.with_tenant(organization) do
          freeze_time do
            entry.clock_out!
            expect(entry.clock_out).to be_within(1.second).of(Time.current)
          end
        end
      end

      it 'accepts custom time' do
        ActsAsTenant.with_tenant(organization) do
          custom_time = Time.current + 2.hours
          entry.clock_out!(time: custom_time)
          expect(entry.clock_out).to eq(custom_time)
        end
      end

      it 'accepts location parameter' do
        ActsAsTenant.with_tenant(organization) do
          entry.clock_out!(location: 'Remote')
          expect(entry.location).to eq('Remote')
        end
      end

      it 'preserves existing location if not provided' do
        ActsAsTenant.with_tenant(organization) do
          entry.update!(location: 'Office')
          entry.clock_out!
          expect(entry.location).to eq('Office')
        end
      end
    end

    describe '#active?' do
      it 'returns true when clock_out is nil' do
        entry = build(:time_entry, :active)
        expect(entry.active?).to be true
      end

      it 'returns false when clock_out is present' do
        entry = build(:time_entry)
        expect(entry.active?).to be false
      end
    end

    describe '#completed?' do
      it 'returns true when clock_out is present' do
        entry = build(:time_entry)
        expect(entry.completed?).to be true
      end

      it 'returns false when clock_out is nil' do
        entry = build(:time_entry, :active)
        expect(entry.completed?).to be false
      end
    end

    describe '#hours_worked' do
      it 'returns hours worked for completed entry' do
        entry = build(:time_entry, duration_minutes: 480) # 8 hours
        expect(entry.hours_worked).to eq(8.0)
      end

      it 'returns 0 for active entry' do
        entry = build(:time_entry, :active)
        expect(entry.hours_worked).to eq(0)
      end

      it 'returns 0 when duration_minutes is nil' do
        entry = build(:time_entry, clock_out: Time.current, duration_minutes: nil)
        expect(entry.hours_worked).to eq(0)
      end
    end

    describe '#overtime?' do
      it 'returns true when working more than 7 hours' do
        entry = build(:time_entry, :overtime)
        expect(entry.overtime?).to be true
      end

      it 'returns false when working 7 hours or less' do
        entry = build(:time_entry, duration_minutes: 420) # 7 hours
        expect(entry.overtime?).to be false
      end

      it 'returns false for active entry' do
        entry = build(:time_entry, :active)
        expect(entry.overtime?).to be false
      end
    end

    describe '#worked_date' do
      it 'returns the date of clock_in' do
        date = Date.current - 2.days
        entry = build(:time_entry, clock_in: date.to_time)
        expect(entry.worked_date).to eq(date)
      end
    end

    describe '#validated?' do
      it 'returns true when validated_at is present' do
        entry = build(:time_entry, :validated)
        expect(entry.validated?).to be true
      end

      it 'returns false when validated_at is nil' do
        entry = build(:time_entry)
        expect(entry.validated?).to be false
      end
    end

    describe '#rejected?' do
      it 'returns true when rejected_at is present' do
        entry = build(:time_entry, :rejected)
        expect(entry.rejected?).to be true
      end

      it 'returns false when rejected_at is nil' do
        entry = build(:time_entry)
        expect(entry.rejected?).to be false
      end
    end

    describe '#late?' do
      let(:work_schedule) { create(:work_schedule, employee: employee, organization: organization) }

      context 'when employee has a schedule' do
        it 'returns false when clocking in on time', skip: 'Weekly schedule plan not implemented yet' do
          ActsAsTenant.with_tenant(organization) do
            # Test implementation pending weekly_schedule_plans
          end
        end

        it 'returns true when clocking in more than 5 minutes late', skip: 'Weekly schedule plan not implemented yet' do
          ActsAsTenant.with_tenant(organization) do
            # Test implementation pending weekly_schedule_plans
          end
        end
      end

      context 'when employee has no schedule' do
        it 'returns false' do
          ActsAsTenant.with_tenant(organization) do
            entry = build(:time_entry, employee: employee, clock_in: Time.current)
            expect(entry.late?).to be false
          end
        end
      end
    end

    describe '#validate!' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let(:entry) { create(:time_entry, employee: employee, organization: organization) }

      it 'validates a completed entry' do
        ActsAsTenant.with_tenant(organization) do
          result = entry.validate!(validator: manager)
          expect(result).to be_truthy
          expect(entry.validated?).to be true
          expect(entry.validated_by).to eq(manager)
        end
      end

      it 'sets validated_at timestamp' do
        ActsAsTenant.with_tenant(organization) do
          freeze_time do
            entry.validate!(validator: manager)
            expect(entry.validated_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      it 'returns false for active entry' do
        ActsAsTenant.with_tenant(organization) do
          active_entry = create(:time_entry, :active, employee: employee, organization: organization)
          result = active_entry.validate!(validator: manager)
          expect(result).to be false
        end
      end

      it 'returns false if already validated' do
        ActsAsTenant.with_tenant(organization) do
          entry.validate!(validator: manager)
          result = entry.validate!(validator: manager)
          expect(result).to be false
        end
      end

      it 'returns false if already rejected' do
        ActsAsTenant.with_tenant(organization) do
          entry.reject!(rejector: manager, reason: 'Invalid')
          result = entry.validate!(validator: manager)
          expect(result).to be false
        end
      end
    end

    describe '#reject!' do
      let(:manager) { create(:employee, :manager, organization: organization) }
      let(:entry) { create(:time_entry, employee: employee, organization: organization) }

      it 'rejects a completed entry' do
        ActsAsTenant.with_tenant(organization) do
          result = entry.reject!(rejector: manager, reason: 'Invalid time')
          expect(result).to be_truthy
          expect(entry.rejected?).to be true
          expect(entry.rejected_by).to eq(manager)
          expect(entry.rejection_reason).to eq('Invalid time')
        end
      end

      it 'sets rejected_at timestamp' do
        ActsAsTenant.with_tenant(organization) do
          freeze_time do
            entry.reject!(rejector: manager, reason: 'Invalid')
            expect(entry.rejected_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      it 'returns false for active entry' do
        ActsAsTenant.with_tenant(organization) do
          active_entry = create(:time_entry, :active, employee: employee, organization: organization)
          result = active_entry.reject!(rejector: manager, reason: 'Invalid')
          expect(result).to be false
        end
      end

      it 'returns false if already validated' do
        ActsAsTenant.with_tenant(organization) do
          entry.validate!(validator: manager)
          result = entry.reject!(rejector: manager, reason: 'Invalid')
          expect(result).to be false
        end
      end

      it 'returns false if already rejected' do
        ActsAsTenant.with_tenant(organization) do
          entry.reject!(rejector: manager, reason: 'Invalid')
          result = entry.reject!(rejector: manager, reason: 'Still invalid')
          expect(result).to be false
        end
      end
    end
  end

  describe 'multi-tenancy' do
    let(:org1) { create(:organization) }
    let(:org2) { create(:organization) }
    let(:emp1) { create(:employee, organization: org1) }
    let(:emp2) { create(:employee, organization: org2) }
    let!(:entry1) { create(:time_entry, employee: emp1, organization: org1) }
    let!(:entry2) { create(:time_entry, employee: emp2, organization: org2) }

    it 'scopes queries to current organization' do
      ActsAsTenant.with_tenant(org1) do
        expect(TimeEntry.all).to include(entry1)
        expect(TimeEntry.all).not_to include(entry2)
      end
    end
  end

  describe 'French labor law compliance' do
    it 'enforces 10-hour daily maximum' do
      ActsAsTenant.with_tenant(organization) do
        entry = build(:time_entry,
                     employee: employee,
                     organization: organization,
                     clock_in: Time.current.change(hour: 7, min: 0),
                     clock_out: Time.current.change(hour: 18, min: 0)) # 11 hours
        # The before_save callback will calculate duration_minutes
        entry.send(:calculate_duration)
        expect(entry).not_to be_valid
        expect(entry.errors[:base]).to include('Cannot exceed 10 hours per day (French legal limit)')
      end
    end
  end
end
