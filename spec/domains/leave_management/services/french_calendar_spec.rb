# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FrenchCalendar do
  describe 'standard French calendar (no region)' do
    subject(:calendar) { described_class.new }

    it 'is not Alsace-Moselle' do
      expect(calendar.alsace_moselle?).to be false
    end

    describe '#holiday?' do
      it 'recognises New Year' do
        expect(calendar.holiday?(Date.new(2025, 1, 1))).to be true
      end

      it 'recognises Easter Monday 2025 (21 avril)' do
        expect(calendar.holiday?(Date.new(2025, 4, 21))).to be true
      end

      it 'recognises Labour Day' do
        expect(calendar.holiday?(Date.new(2025, 5, 1))).to be true
      end

      it 'recognises Christmas' do
        expect(calendar.holiday?(Date.new(2025, 12, 25))).to be true
      end

      it 'does NOT recognise Good Friday' do
        # Good Friday 2025 = 18 April
        expect(calendar.holiday?(Date.new(2025, 4, 18))).to be false
      end

      it 'does NOT recognise 26 December' do
        expect(calendar.holiday?(Date.new(2025, 12, 26))).to be false
      end

      it 'includes all 11 standard holidays in 2025' do
        holidays = (Date.new(2025, 1, 1)..Date.new(2025, 12, 31)).select { |d| calendar.holiday?(d) }
        expect(holidays.size).to eq(11)
      end
    end

    describe '#working_days_between' do
      it 'counts 0 for a single weekend day' do
        expect(calendar.working_days_between(Date.new(2025, 1, 4), Date.new(2025, 1, 5))).to eq(0)
      end

      it 'counts 5 working days in a normal week' do
        # Mon 6 Jan → Fri 10 Jan 2025
        expect(calendar.working_days_between(Date.new(2025, 1, 6), Date.new(2025, 1, 10))).to eq(5)
      end

      it 'excludes Easter Monday from working days (week of 21 Apr 2025)' do
        # Mon 21 Apr (Easter Monday) → Fri 25 Apr = 4 working days
        expect(calendar.working_days_between(Date.new(2025, 4, 21), Date.new(2025, 4, 25))).to eq(4)
      end
    end
  end

  describe 'Alsace-Moselle region' do
    subject(:calendar) { described_class.new(region: :alsace_moselle) }

    it 'is Alsace-Moselle' do
      expect(calendar.alsace_moselle?).to be true
    end

    describe '#holiday?' do
      # Good Friday 2025 = 18 April (Easter Sunday 2025 = 20 April)
      it 'recognises Good Friday (Vendredi Saint)' do
        expect(calendar.holiday?(Date.new(2025, 4, 18))).to be true
      end

      it 'recognises 26 December (Saint-Étienne)' do
        expect(calendar.holiday?(Date.new(2025, 12, 26))).to be true
      end

      it 'still recognises all 11 standard holidays' do
        expect(calendar.holiday?(Date.new(2025, 1, 1))).to be true
        expect(calendar.holiday?(Date.new(2025, 12, 25))).to be true
      end

      it 'includes 13 holidays in 2025' do
        holidays = (Date.new(2025, 1, 1)..Date.new(2025, 12, 31)).select { |d| calendar.holiday?(d) }
        expect(holidays.size).to eq(13)
      end

      # Good Friday 2026 = 3 April (Easter Sunday 2026 = 5 April)
      it 'correctly computes Good Friday for 2026' do
        expect(calendar.holiday?(Date.new(2026, 4, 3))).to be true
      end
    end

    describe '#working_days_between with Alsace-Moselle holidays' do
      # Week of Good Friday 2025: Fri 18 Apr (Good Friday) → Mon 21 Apr (Easter Monday)
      # Only Tue 22, Wed 23, Thu 24, Fri 25 are working = 4 days in the full week
      it 'excludes Good Friday from working days' do
        # Thu 17 Apr → Tue 22 Apr (spans Good Friday + Easter Monday weekend)
        # 17 Apr = 1 day, 18 Apr = Good Friday (holiday), 19-20 = weekend, 21 Apr = Easter Monday (holiday), 22 Apr = 1 day
        expect(calendar.working_days_between(Date.new(2025, 4, 17), Date.new(2025, 4, 22))).to eq(2)
      end

      it 'excludes 26 December from working days' do
        # Fri 26 Dec 2025 is Saint-Étienne — not a working day
        expect(calendar.working_days_between(Date.new(2025, 12, 26), Date.new(2025, 12, 26))).to eq(0)
      end

      it 'counts more working days than standard calendar in the same week (Good Friday week)' do
        standard = described_class.new
        alsace   = described_class.new(region: :alsace_moselle)

        week = calendar.working_days_between(Date.new(2025, 4, 14), Date.new(2025, 4, 25))
        standard_week = standard.working_days_between(Date.new(2025, 4, 14), Date.new(2025, 4, 25))

        expect(alsace.working_days_between(Date.new(2025, 4, 14), Date.new(2025, 4, 25)))
          .to eq(standard_week - 1)
      end
    end
  end
end
