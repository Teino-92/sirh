# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkSchedule, type: :model do
  let(:organization) { create(:organization) }
  let(:employee) { create(:employee, organization: organization) }
  let(:work_schedule) { build(:work_schedule, employee: employee, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:employee) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:weekly_hours) }
    it { is_expected.to validate_presence_of(:schedule_pattern) }

    it do
      is_expected.to validate_numericality_of(:weekly_hours)
        .is_greater_than(0)
        .is_less_than_or_equal_to(48)
    end

    context 'with valid attributes' do
      it 'is valid' do
        ActsAsTenant.with_tenant(organization) do
          expect(work_schedule).to be_valid
        end
      end
    end

    describe 'weekly_hours validation' do
      it 'is invalid when weekly_hours is 0' do
        ActsAsTenant.with_tenant(organization) do
          work_schedule.weekly_hours = 0
          expect(work_schedule).not_to be_valid
        end
      end

      it 'is invalid when weekly_hours is negative' do
        ActsAsTenant.with_tenant(organization) do
          work_schedule.weekly_hours = -5
          expect(work_schedule).not_to be_valid
        end
      end

      it 'is invalid when exceeding 48 hours (French legal maximum)' do
        ActsAsTenant.with_tenant(organization) do
          work_schedule.weekly_hours = 49
          expect(work_schedule).not_to be_valid
        end
      end

      it 'is valid at exactly 48 hours (French legal maximum)' do
        ActsAsTenant.with_tenant(organization) do
          work_schedule.weekly_hours = 48
          expect(work_schedule).to be_valid
        end
      end

      it 'is valid at standard 35 hours' do
        ActsAsTenant.with_tenant(organization) do
          work_schedule.weekly_hours = 35
          expect(work_schedule).to be_valid
        end
      end
    end

    describe 'employee_id uniqueness' do
      it 'allows only one schedule per employee' do
        ActsAsTenant.with_tenant(organization) do
          create(:work_schedule, employee: employee, organization: organization)
          duplicate_schedule = build(:work_schedule, employee: employee, organization: organization)
          expect(duplicate_schedule).not_to be_valid
        end
      end

      it 'allows different employees to have schedules' do
        ActsAsTenant.with_tenant(organization) do
          employee2 = create(:employee, organization: organization)
          create(:work_schedule, employee: employee, organization: organization)
          schedule2 = build(:work_schedule, employee: employee2, organization: organization)
          expect(schedule2).to be_valid
        end
      end
    end

    describe 'employee_belongs_to_same_organization validation' do
      it 'is invalid when employee belongs to different organization' do
        other_org = create(:organization)
        other_employee = create(:employee, organization: other_org)

        ActsAsTenant.with_tenant(organization) do
          work_schedule.employee = other_employee
          expect(work_schedule).not_to be_valid
          expect(work_schedule.errors[:employee]).to include('must belong to the same organization')
        end
      end
    end
  end

  describe 'TEMPLATES constant' do
    it 'includes full_time_35h template' do
      expect(WorkSchedule::TEMPLATES['full_time_35h']).to be_present
      expect(WorkSchedule::TEMPLATES['full_time_35h'][:weekly_hours]).to eq(35)
    end

    it 'includes full_time_39h template' do
      expect(WorkSchedule::TEMPLATES['full_time_39h']).to be_present
      expect(WorkSchedule::TEMPLATES['full_time_39h'][:weekly_hours]).to eq(39)
    end

    it 'includes part_time_24h template' do
      expect(WorkSchedule::TEMPLATES['part_time_24h']).to be_present
      expect(WorkSchedule::TEMPLATES['part_time_24h'][:weekly_hours]).to eq(24)
    end

    it 'has correct schedule patterns' do
      template = WorkSchedule::TEMPLATES['full_time_35h']
      expect(template[:schedule_pattern]).to have_key('monday')
      expect(template[:schedule_pattern]).to have_key('friday')
      expect(template[:schedule_pattern]['monday']).to eq('09:00-17:00')
    end
  end

  describe '.create_from_template' do
    it 'creates schedule from full_time_35h template' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'full_time_35h')
        expect(schedule).to be_persisted
        expect(schedule.weekly_hours).to eq(35)
        expect(schedule.name).to eq('35h - Temps plein')
      end
    end

    it 'creates schedule from full_time_39h template' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'full_time_39h')
        expect(schedule).to be_persisted
        expect(schedule.weekly_hours).to eq(39)
        expect(schedule.name).to eq('39h - Temps plein avec RTT')
      end
    end

    it 'creates schedule from part_time_24h template' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'part_time_24h')
        expect(schedule).to be_persisted
        expect(schedule.weekly_hours).to eq(24)
        expect(schedule.name).to eq('24h - Temps partiel (3/5)')
      end
    end

    it 'sets correct schedule_pattern from template' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'full_time_35h')
        expect(schedule.schedule_pattern['monday']).to eq('09:00-17:00')
        expect(schedule.schedule_pattern['friday']).to eq('09:00-17:00')
      end
    end

    it 'associates schedule with employee organization' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'full_time_35h')
        expect(schedule.organization).to eq(employee.organization)
      end
    end

    it 'raises error for unknown template' do
      ActsAsTenant.with_tenant(organization) do
        expect {
          WorkSchedule.create_from_template(employee, 'unknown_template')
        }.to raise_error(ArgumentError, 'Unknown template: unknown_template')
      end
    end
  end

  describe 'callbacks' do
    describe 'after_save :calculate_rtt_rate' do
      context 'when RTT eligible' do
        let(:org_with_rtt) { create(:organization, :with_39_hour_week) }
        let(:employee_rtt) { create(:employee, organization: org_with_rtt) }

        it 'calculates RTT accrual rate for 39h schedule' do
          ActsAsTenant.with_tenant(org_with_rtt) do
            schedule = create(:work_schedule, :full_time_39h, employee: employee_rtt, organization: org_with_rtt)
            expect(schedule.rtt_accrual_rate).to be_present
            expect(schedule.rtt_accrual_rate).to be > 0
          end
        end

        it 'does not set RTT rate for 35h schedule' do
          ActsAsTenant.with_tenant(org_with_rtt) do
            schedule = create(:work_schedule, :full_time_35h, employee: employee_rtt, organization: org_with_rtt)
            # 35h schedule is not RTT eligible, so rate should be 0 or nil
            expect([0.0, nil]).to include(schedule.rtt_accrual_rate)
          end
        end
      end

      context 'when RTT not enabled' do
        let(:org_without_rtt) { create(:organization, :with_rtt_disabled) }
        let(:employee_no_rtt) { create(:employee, organization: org_without_rtt) }

        it 'does not calculate RTT rate even for 39h schedule' do
          ActsAsTenant.with_tenant(org_without_rtt) do
            schedule = create(:work_schedule, :full_time_39h, employee: employee_no_rtt, organization: org_without_rtt)
            # RTT not enabled, so rate should be 0 or nil
            expect([0.0, nil]).to include(schedule.rtt_accrual_rate)
          end
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#full_time?' do
      it 'returns true for 35 hours' do
        work_schedule.weekly_hours = 35
        expect(work_schedule.full_time?).to be true
      end

      it 'returns true for hours above 35' do
        work_schedule.weekly_hours = 39
        expect(work_schedule.full_time?).to be true
      end

      it 'returns false for hours below 35' do
        work_schedule.weekly_hours = 24
        expect(work_schedule.full_time?).to be false
      end
    end

    describe '#part_time?' do
      it 'returns true for hours below 35' do
        work_schedule.weekly_hours = 24
        expect(work_schedule.part_time?).to be true
      end

      it 'returns false for 35 hours' do
        work_schedule.weekly_hours = 35
        expect(work_schedule.part_time?).to be false
      end

      it 'returns false for hours above 35' do
        work_schedule.weekly_hours = 39
        expect(work_schedule.part_time?).to be false
      end
    end

    describe '#works_on?' do
      it 'returns true for scheduled days' do
        expect(work_schedule.works_on?('monday')).to be true
        expect(work_schedule.works_on?('tuesday')).to be true
      end

      it 'returns false for non-scheduled days' do
        expect(work_schedule.works_on?('saturday')).to be false
        expect(work_schedule.works_on?('sunday')).to be false
      end

      it 'accepts string day names' do
        expect(work_schedule.works_on?('monday')).to be true
      end

      it 'accepts symbol day names' do
        expect(work_schedule.works_on?(:monday)).to be true
      end

      it 'is case-insensitive' do
        expect(work_schedule.works_on?('Monday')).to be true
        expect(work_schedule.works_on?('MONDAY')).to be true
      end
    end

    describe '#hours_for_day' do
      it 'calculates hours for scheduled day' do
        # Default schedule: 09:00-17:00 = 8 hours
        expect(work_schedule.hours_for_day('monday')).to eq(8.0)
      end

      it 'returns 0 for non-scheduled day' do
        expect(work_schedule.hours_for_day('saturday')).to eq(0)
      end

      it 'handles different time formats correctly' do
        ActsAsTenant.with_tenant(organization) do
          schedule = create(:work_schedule, :full_time_39h, employee: employee, organization: organization)
          # 39h schedule has 09:00-18:00 for most days = 9 hours
          expect(schedule.hours_for_day('monday')).to eq(9.0)
        end
      end

      it 'accepts string day names' do
        expect(work_schedule.hours_for_day('tuesday')).to eq(8.0)
      end

      it 'accepts symbol day names' do
        expect(work_schedule.hours_for_day(:tuesday)).to eq(8.0)
      end
    end

    describe '#daily_hours' do
      it 'returns hash of hours per day' do
        result = work_schedule.daily_hours
        expect(result).to be_a(Hash)
        expect(result['monday']).to eq(8.0)
        expect(result['tuesday']).to eq(8.0)
      end

      it 'calculates hours for all scheduled days' do
        result = work_schedule.daily_hours
        expect(result.keys).to include('monday', 'tuesday', 'wednesday', 'thursday', 'friday')
      end

      it 'handles different schedules correctly' do
        ActsAsTenant.with_tenant(organization) do
          schedule = create(:work_schedule, :part_time_24h, employee: employee, organization: organization)
          result = schedule.daily_hours
          expect(result['monday']).to eq(8.0)
          expect(result['tuesday']).to eq(8.0)
          expect(result['wednesday']).to eq(8.0)
          expect(result['thursday']).to be_nil # Not in part-time schedule
        end
      end
    end

    describe '#working_days' do
      it 'returns array of working day names' do
        days = work_schedule.working_days
        expect(days).to be_an(Array)
        expect(days).to include('monday', 'tuesday', 'wednesday', 'thursday', 'friday')
      end

      it 'does not include non-working days' do
        days = work_schedule.working_days
        expect(days).not_to include('saturday', 'sunday')
      end

      it 'returns correct days for part-time schedule' do
        ActsAsTenant.with_tenant(organization) do
          schedule = create(:work_schedule, :part_time_24h, employee: employee, organization: organization)
          days = schedule.working_days
          expect(days.length).to eq(3)
          expect(days).to include('monday', 'tuesday', 'wednesday')
        end
      end
    end

    describe '#rtt_eligible?' do
      context 'with RTT enabled organization' do
        let(:org_with_rtt) { create(:organization, :with_39_hour_week) }
        let(:employee_rtt) { create(:employee, organization: org_with_rtt) }

        it 'returns true for schedule over 35h' do
          ActsAsTenant.with_tenant(org_with_rtt) do
            schedule = build(:work_schedule, :full_time_39h, employee: employee_rtt, organization: org_with_rtt)
            expect(schedule.rtt_eligible?).to be true
          end
        end

        it 'returns false for schedule at 35h' do
          ActsAsTenant.with_tenant(org_with_rtt) do
            schedule = build(:work_schedule, :full_time_35h, employee: employee_rtt, organization: org_with_rtt)
            expect(schedule.rtt_eligible?).to be false
          end
        end

        it 'returns false for part-time schedule' do
          ActsAsTenant.with_tenant(org_with_rtt) do
            schedule = build(:work_schedule, :part_time_24h, employee: employee_rtt, organization: org_with_rtt)
            expect(schedule.rtt_eligible?).to be false
          end
        end
      end

      context 'with RTT disabled organization' do
        let(:org_without_rtt) { create(:organization, :with_rtt_disabled) }
        let(:employee_no_rtt) { create(:employee, organization: org_without_rtt) }

        it 'returns false even for schedule over 35h' do
          ActsAsTenant.with_tenant(org_without_rtt) do
            schedule = build(:work_schedule, :full_time_39h, employee: employee_no_rtt, organization: org_without_rtt)
            expect(schedule.rtt_eligible?).to be false
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
    let!(:schedule1) { create(:work_schedule, employee: emp1, organization: org1) }
    let!(:schedule2) { create(:work_schedule, employee: emp2, organization: org2) }

    it 'scopes queries to current organization' do
      ActsAsTenant.with_tenant(org1) do
        expect(WorkSchedule.all).to include(schedule1)
        expect(WorkSchedule.all).not_to include(schedule2)
      end
    end
  end

  describe 'French labor law compliance' do
    it 'enforces 48-hour weekly maximum' do
      ActsAsTenant.with_tenant(organization) do
        schedule = build(:work_schedule, employee: employee, organization: organization, weekly_hours: 50)
        expect(schedule).not_to be_valid
      end
    end

    it 'accepts 48-hour weekly maximum' do
      ActsAsTenant.with_tenant(organization) do
        schedule = build(:work_schedule, :max_hours, employee: employee, organization: organization)
        expect(schedule).to be_valid
      end
    end

    it 'accepts standard 35-hour work week' do
      ActsAsTenant.with_tenant(organization) do
        schedule = build(:work_schedule, :full_time_35h, employee: employee, organization: organization)
        expect(schedule).to be_valid
        expect(schedule.weekly_hours).to eq(35)
      end
    end

    it 'supports 39-hour work week with RTT' do
      ActsAsTenant.with_tenant(organization) do
        schedule = build(:work_schedule, :full_time_39h, employee: employee, organization: organization)
        expect(schedule).to be_valid
        expect(schedule.weekly_hours).to eq(39)
      end
    end
  end

  describe 'template scenarios' do
    it 'supports full-time 35h standard French schedule' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'full_time_35h')
        expect(schedule.full_time?).to be true
        expect(schedule.working_days.length).to eq(5)
        expect(schedule.hours_for_day('monday')).to eq(8.0)
      end
    end

    it 'supports full-time 39h with RTT eligibility' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'full_time_39h')
        expect(schedule.full_time?).to be true
        expect(schedule.weekly_hours).to eq(39)
        expect(schedule.rtt_eligible?).to be true
      end
    end

    it 'supports part-time 24h (3/5) schedule' do
      ActsAsTenant.with_tenant(organization) do
        schedule = WorkSchedule.create_from_template(employee, 'part_time_24h')
        expect(schedule.part_time?).to be true
        expect(schedule.working_days.length).to eq(3)
        expect(schedule.rtt_eligible?).to be false
      end
    end
  end

  describe 'schedule pattern validation' do
    it 'accepts valid time format' do
      ActsAsTenant.with_tenant(organization) do
        work_schedule.schedule_pattern = { 'monday' => '09:00-17:00' }
        expect(work_schedule).to be_valid
      end
    end

    it 'handles various time formats' do
      ActsAsTenant.with_tenant(organization) do
        work_schedule.schedule_pattern = {
          'monday' => '08:00-16:00',
          'tuesday' => '09:30-17:30',
          'wednesday' => '10:00-18:00'
        }
        expect(work_schedule.hours_for_day('monday')).to eq(8.0)
        expect(work_schedule.hours_for_day('tuesday')).to eq(8.0)
        expect(work_schedule.hours_for_day('wednesday')).to eq(8.0)
      end
    end
  end
end
