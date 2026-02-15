# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organization, type: :model do
  let(:organization) { build(:organization) }

  describe 'associations' do
    it { is_expected.to have_many(:employees).dependent(:destroy) }

    context 'dependent destroy behavior' do
      it 'destroys associated employees when organization is destroyed' do
        org = create(:organization)
        employee1 = create(:employee, organization: org)
        employee2 = create(:employee, organization: org)

        expect { org.destroy }.to change { Employee.count }.by(-2)
        expect(Employee.where(id: [employee1.id, employee2.id])).to be_empty
      end

      it 'does not affect employees from other organizations' do
        org1 = create(:organization)
        org2 = create(:organization)
        employee1 = create(:employee, organization: org1)
        employee2 = create(:employee, organization: org2)

        expect { org1.destroy }.not_to change { Employee.where(id: employee2.id).count }
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }

    it 'is invalid without a name' do
      organization.name = nil
      expect(organization).not_to be_valid
      expect(organization.errors[:name]).to include("doit être rempli(e)")
    end

    it 'is invalid with blank name' do
      organization.name = ''
      expect(organization).not_to be_valid
      expect(organization.errors[:name]).to include("doit être rempli(e)")
    end

    it 'is invalid with whitespace-only name' do
      organization.name = '   '
      expect(organization).not_to be_valid
      expect(organization.errors[:name]).to include("doit être rempli(e)")
    end

    it 'is valid with a name' do
      organization.name = 'TechCorp SA'
      expect(organization).to be_valid
    end

    it 'is valid with all attributes properly set' do
      org = build(:organization,
                  name: 'Acme Corporation',
                  settings: {
                    work_week_hours: 35,
                    cp_acquisition_rate: 2.5,
                    rtt_enabled: true
                  })
      expect(org).to be_valid
    end
  end

  describe 'callbacks' do
    describe 'after_initialize :ensure_settings' do
      it 'initializes settings as empty hash for new record' do
        new_org = Organization.new
        expect(new_org.settings).to eq({})
      end

      it 'initializes settings as empty hash when name is provided' do
        new_org = Organization.new(name: 'Test Corp')
        expect(new_org.settings).to eq({})
      end

      it 'does not overwrite existing settings' do
        new_org = Organization.new(name: 'Test Corp', settings: { custom: 'value' })
        expect(new_org.settings).to eq({ 'custom' => 'value' })
      end

      it 'ensures settings is not nil after initialization' do
        new_org = Organization.new(name: 'Test Corp')
        new_org.settings = nil
        new_org.send(:ensure_settings)
        expect(new_org.settings).to eq({})
      end

    end
  end

  describe '#default_settings' do
    it 'returns a hash with all default keys' do
      defaults = organization.default_settings
      expect(defaults).to be_a(Hash)
      expect(defaults.keys).to match_array([
        :work_week_hours,
        :cp_acquisition_rate,
        :cp_expiry_month,
        :cp_expiry_day,
        :rtt_enabled,
        :overtime_threshold,
        :max_daily_hours,
        :min_consecutive_leave_days
      ])
    end

    it 'returns work_week_hours as 35' do
      expect(organization.default_settings[:work_week_hours]).to eq(35)
    end

    it 'returns cp_acquisition_rate as 2.5' do
      expect(organization.default_settings[:cp_acquisition_rate]).to eq(2.5)
    end

    it 'returns cp_expiry_month as 5 (May)' do
      expect(organization.default_settings[:cp_expiry_month]).to eq(5)
    end

    it 'returns cp_expiry_day as 31' do
      expect(organization.default_settings[:cp_expiry_day]).to eq(31)
    end

    it 'returns rtt_enabled as true' do
      expect(organization.default_settings[:rtt_enabled]).to eq(true)
    end

    it 'returns overtime_threshold as 35' do
      expect(organization.default_settings[:overtime_threshold]).to eq(35)
    end

    it 'returns max_daily_hours as 10' do
      expect(organization.default_settings[:max_daily_hours]).to eq(10)
    end

    it 'returns min_consecutive_leave_days as 10' do
      expect(organization.default_settings[:min_consecutive_leave_days]).to eq(10)
    end

    it 'returns the same hash on multiple calls' do
      first_call = organization.default_settings
      second_call = organization.default_settings
      expect(first_call).to eq(second_call)
    end

    it 'has exactly 8 default settings' do
      expect(organization.default_settings.size).to eq(8)
    end
  end

  describe '#work_week_hours' do
    context 'with default settings' do
      it 'returns 35 when settings is empty' do
        organization.settings = {}
        expect(organization.work_week_hours).to eq(35)
      end

      it 'returns 35 when settings is nil' do
        organization.settings = nil
        organization.send(:ensure_settings)
        expect(organization.work_week_hours).to eq(35)
      end

      it 'returns 35 when work_week_hours key is missing' do
        organization.settings = { other_setting: 'value' }
        expect(organization.work_week_hours).to eq(35)
      end
    end

    context 'with custom settings' do
      it 'returns custom value from settings hash' do
        organization.settings = { 'work_week_hours' => 39 }
        expect(organization.work_week_hours).to eq(39)
      end

      it 'handles string keys in settings hash' do
        organization.settings = { 'work_week_hours' => 37 }
        expect(organization.work_week_hours).to eq(37)
      end

      it 'returns custom value when set to 0' do
        organization.settings = { 'work_week_hours' => 0 }
        expect(organization.work_week_hours).to eq(0)
      end

      it 'returns custom value when set to 40' do
        organization.settings = { 'work_week_hours' => 40 }
        expect(organization.work_week_hours).to eq(40)
      end

      it 'handles fractional hours' do
        organization.settings = { 'work_week_hours' => 37.5 }
        expect(organization.work_week_hours).to eq(37.5)
      end
    end

    context 'with persisted organization' do
      it 'returns value from database' do
        org = create(:organization, settings: { 'work_week_hours' => 39 })
        expect(org.work_week_hours).to eq(39)
      end
    end
  end

  describe '#rtt_enabled?' do
    context 'with default settings' do
      it 'returns true when settings is empty' do
        organization.settings = {}
        expect(organization.rtt_enabled?).to be true
      end

      it 'returns true when settings is nil' do
        organization.settings = nil
        organization.send(:ensure_settings)
        expect(organization.rtt_enabled?).to be true
      end

      it 'returns true when rtt_enabled key is missing' do
        organization.settings = { other_setting: 'value' }
        expect(organization.rtt_enabled?).to be true
      end
    end

    context 'with custom settings' do
      it 'returns false when explicitly set to false' do
        organization.settings = { 'rtt_enabled' => false }
        expect(organization.rtt_enabled?).to be false
      end

      it 'returns true when explicitly set to true' do
        organization.settings = { 'rtt_enabled' => true }
        expect(organization.rtt_enabled?).to be true
      end

      it 'handles boolean false value' do
        organization.settings = { 'rtt_enabled' => false }
        expect(organization.rtt_enabled?).to eq(false)
        expect(organization.rtt_enabled?).not_to be_nil
      end

      it 'handles boolean true value' do
        organization.settings = { 'rtt_enabled' => true }
        expect(organization.rtt_enabled?).to eq(true)
      end

      it 'handles string keys in settings hash' do
        organization.settings = { 'rtt_enabled' => false }
        expect(organization.rtt_enabled?).to be false
      end
    end

    context 'with persisted organization' do
      it 'returns value from database' do
        org = create(:organization, :with_rtt_disabled)
        expect(org.rtt_enabled?).to be false
      end

      it 'returns true for default factory' do
        org = create(:organization)
        expect(org.rtt_enabled?).to be true
      end
    end
  end

  describe 'custom settings storage' do
    it 'can store arbitrary settings' do
      organization.settings = { custom_key: 'custom_value' }
      expect(organization.settings['custom_key']).to eq('custom_value')
    end

    it 'persists custom settings to database' do
      org = create(:organization, settings: { custom_field: 'test_value' })
      reloaded_org = Organization.find(org.id)
      expect(reloaded_org.settings['custom_field']).to eq('test_value')
    end

    it 'can store multiple custom settings' do
      organization.settings = {
        setting1: 'value1',
        setting2: 'value2',
        setting3: 'value3'
      }
      expect(organization.settings.keys.size).to eq(3)
    end

    it 'can update individual settings' do
      org = create(:organization)
      org.settings['new_setting'] = 'new_value'
      org.save!
      org.reload
      expect(org.settings['new_setting']).to eq('new_value')
    end

    it 'preserves existing settings when adding new ones' do
      org = create(:organization, settings: { existing: 'value' })
      org.settings['new_key'] = 'new_value'
      org.save!
      org.reload
      expect(org.settings['existing']).to eq('value')
      expect(org.settings['new_key']).to eq('new_value')
    end

    it 'can store nested hash structures' do
      organization.settings = {
        notifications: {
          email: true,
          sms: false
        }
      }
      expect(organization.settings['notifications']['email']).to be true
      expect(organization.settings['notifications']['sms']).to be false
    end

    it 'can store array values' do
      organization.settings = { holidays: ['2025-01-01', '2025-05-01', '2025-07-14'] }
      expect(organization.settings['holidays']).to be_an(Array)
      expect(organization.settings['holidays'].size).to eq(3)
    end

    it 'can override default settings' do
      org = create(:organization, settings: { work_week_hours: 40, rtt_enabled: false })
      expect(org.work_week_hours).to eq(40)
      expect(org.rtt_enabled?).to be false
    end
  end

  describe 'French legal compliance defaults' do
    context '35-hour work week (French standard)' do
      it 'defaults to 35 hours per week' do
        expect(organization.default_settings[:work_week_hours]).to eq(35)
      end

      it 'uses 35 hours for overtime threshold calculation' do
        expect(organization.default_settings[:overtime_threshold]).to eq(35)
      end

      it 'can be customized for organizations with different agreements' do
        org = create(:organization, :with_39_hour_week)
        expect(org.work_week_hours).to eq(39)
      end
    end

    context '10-hour maximum daily hours (French legal limit)' do
      it 'defaults to 10 hours max per day' do
        expect(organization.default_settings[:max_daily_hours]).to eq(10)
      end

      it 'enforces French labor law Article L3121-18' do
        # French law: maximum 10 hours per day (can be extended to 12h with derogation)
        expect(organization.default_settings[:max_daily_hours]).to eq(10)
      end
    end

    context 'CP (Congés Payés) defaults' do
      it 'defaults to 2.5 days accrual per month' do
        expect(organization.default_settings[:cp_acquisition_rate]).to eq(2.5)
      end

      it 'defaults CP expiry to May 31 (French legal requirement)' do
        expect(organization.default_settings[:cp_expiry_month]).to eq(5)
        expect(organization.default_settings[:cp_expiry_day]).to eq(31)
      end

      it 'sets expiry date compliant with Article L3141-13' do
        # French law: CP must be taken within 12 months, typically expires May 31
        defaults = organization.default_settings
        expect(defaults[:cp_expiry_month]).to eq(5)
        expect(defaults[:cp_expiry_day]).to eq(31)
      end

      it 'allows 2.5 days/month * 12 months = 30 days/year' do
        rate = organization.default_settings[:cp_acquisition_rate]
        annual_cp = rate * 12
        expect(annual_cp).to eq(30.0)
      end
    end

    context 'RTT (Réduction du Temps de Travail)' do
      it 'defaults to RTT enabled' do
        expect(organization.default_settings[:rtt_enabled]).to be true
      end

      it 'applies to organizations with >35 hour work weeks' do
        org = create(:organization, :with_39_hour_week)
        expect(org.rtt_enabled?).to be true
      end

      it 'can be disabled for part-time or 35h organizations' do
        org = create(:organization, :with_rtt_disabled)
        expect(org.rtt_enabled?).to be false
      end
    end

    context 'minimum consecutive leave days' do
      it 'defaults to 10 days minimum consecutive leave' do
        expect(organization.default_settings[:min_consecutive_leave_days]).to eq(10)
      end

      it 'enforces French requirement for 12 consecutive working days of CP (≈10 days)' do
        # French law: Employees must take at least 12 consecutive working days
        # (approximately 10 calendar days) during summer period (May 1 - Oct 31)
        expect(organization.default_settings[:min_consecutive_leave_days]).to eq(10)
      end
    end
  end

  describe 'factory traits' do
    it 'creates organization with default settings using factory' do
      org = create(:organization)
      expect(org.work_week_hours).to eq(35)
      expect(org.rtt_enabled?).to be true
    end

    it 'creates organization with RTT disabled using :with_rtt_disabled trait' do
      org = create(:organization, :with_rtt_disabled)
      expect(org.rtt_enabled?).to be false
      expect(org.settings['rtt_enabled']).to be false
    end

    it 'creates organization with 39-hour week using :with_39_hour_week trait' do
      org = create(:organization, :with_39_hour_week)
      expect(org.work_week_hours).to eq(39)
      expect(org.settings['work_week_hours']).to eq(39)
    end
  end

  describe 'settings accessor method behavior' do
    it 'uses Hash#fetch with default fallback' do
      organization.settings = {}
      # Should fetch with default from default_settings
      expect(organization.work_week_hours).to eq(35)
    end

    it 'prioritizes stored value over default' do
      organization.settings = { 'work_week_hours' => 40 }
      expect(organization.work_week_hours).to eq(40)
      expect(organization.work_week_hours).not_to eq(organization.default_settings[:work_week_hours])
    end

    it 'handles symbol vs string key differences' do
      # Factory uses symbol keys, but database stores as string keys
      org = create(:organization)
      expect(org.settings.keys.first).to be_a(String)
    end
  end

  describe 'real-world usage scenarios' do
    context 'startup with default French legal compliance' do
      it 'can create organization with zero configuration' do
        org = Organization.create!(name: 'Startup SAS')
        expect(org.work_week_hours).to eq(35)
        expect(org.default_settings[:cp_acquisition_rate]).to eq(2.5)
        expect(org.default_settings[:max_daily_hours]).to eq(10)
      end
    end

    context 'enterprise with custom agreements' do
      it 'can override work hours while keeping other defaults' do
        org = create(:organization, settings: { 'work_week_hours' => 37 })
        expect(org.work_week_hours).to eq(37)
        expect(org.default_settings[:cp_acquisition_rate]).to eq(2.5)
        expect(org.default_settings[:max_daily_hours]).to eq(10)
      end
    end

    context 'organization without RTT' do
      it 'can disable RTT for part-time workers or small companies' do
        org = create(:organization, :with_rtt_disabled)
        expect(org.rtt_enabled?).to be false
        expect(org.work_week_hours).to eq(35)
      end
    end

    context 'updating settings over time' do
      it 'can update single setting without affecting others' do
        org = create(:organization)
        original_cp_rate = org.default_settings[:cp_acquisition_rate]

        org.settings['work_week_hours'] = 39
        org.save!

        expect(org.work_week_hours).to eq(39)
        expect(org.default_settings[:cp_acquisition_rate]).to eq(original_cp_rate)
      end
    end
  end

  describe 'settings migration and versioning' do
    it 'preserves unknown settings for backward compatibility' do
      org = create(:organization, settings: { 'future_setting' => 'value' })
      expect(org.settings['future_setting']).to eq('value')
    end
  end

  describe 'multi-tenant isolation' do
    it 'each organization has independent settings' do
      org1 = create(:organization, settings: { 'work_week_hours' => 35 })
      org2 = create(:organization, settings: { 'work_week_hours' => 39 })

      expect(org1.work_week_hours).to eq(35)
      expect(org2.work_week_hours).to eq(39)
    end

    it 'employees belong to organization with specific settings' do
      org_35h = create(:organization, settings: { 'work_week_hours' => 35 })
      org_39h = create(:organization, settings: { 'work_week_hours' => 39 })

      employee1 = create(:employee, organization: org_35h)
      employee2 = create(:employee, organization: org_39h)

      expect(employee1.organization.work_week_hours).to eq(35)
      expect(employee2.organization.work_week_hours).to eq(39)
    end
  end

  describe 'JSON serialization' do
    it 'properly serializes and deserializes settings hash' do
      original_settings = {
        'work_week_hours' => 37,
        'custom_field' => 'value',
        'nested' => { 'key' => 'value' }
      }

      org = create(:organization, settings: original_settings)
      reloaded = Organization.find(org.id)

      expect(reloaded.settings).to eq(original_settings)
    end
  end

  describe 'edge cases' do
    it 'handles empty string name' do
      org = build(:organization, name: '')
      expect(org).not_to be_valid
    end

    it 'handles very long organization name' do
      org = build(:organization, name: 'A' * 255)
      # Assuming no length validation, this should be valid
      expect(org).to be_valid
    end

    it 'handles special characters in name' do
      org = build(:organization, name: "L'Oréal S.A. & Cie")
      expect(org).to be_valid
    end

    it 'handles unicode characters in name' do
      org = build(:organization, name: 'Société Générale')
      expect(org).to be_valid
    end
  end
end
