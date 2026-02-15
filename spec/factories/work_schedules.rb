# frozen_string_literal: true

FactoryBot.define do
  factory :work_schedule do
    employee
    organization { employee.organization }
    name { '35h - Temps plein' }
    weekly_hours { 35 }
    schedule_pattern do
      {
        'monday' => '09:00-17:00',
        'tuesday' => '09:00-17:00',
        'wednesday' => '09:00-17:00',
        'thursday' => '09:00-17:00',
        'friday' => '09:00-17:00'
      }
    end

    trait :full_time_35h do
      name { '35h - Temps plein' }
      weekly_hours { 35 }
      schedule_pattern do
        {
          'monday' => '09:00-17:00',
          'tuesday' => '09:00-17:00',
          'wednesday' => '09:00-17:00',
          'thursday' => '09:00-17:00',
          'friday' => '09:00-17:00'
        }
      end
    end

    trait :full_time_39h do
      name { '39h - Temps plein avec RTT' }
      weekly_hours { 39 }
      schedule_pattern do
        {
          'monday' => '09:00-18:00',
          'tuesday' => '09:00-18:00',
          'wednesday' => '09:00-18:00',
          'thursday' => '09:00-18:00',
          'friday' => '09:00-17:00'
        }
      end
    end

    trait :part_time_24h do
      name { '24h - Temps partiel (3/5)' }
      weekly_hours { 24 }
      schedule_pattern do
        {
          'monday' => '09:00-17:00',
          'tuesday' => '09:00-17:00',
          'wednesday' => '09:00-17:00'
        }
      end
    end

    trait :part_time_28h do
      name { '28h - Temps partiel (4/5)' }
      weekly_hours { 28 }
      schedule_pattern do
        {
          'monday' => '09:00-17:00',
          'tuesday' => '09:00-17:00',
          'wednesday' => '09:00-17:00',
          'thursday' => '09:00-17:00'
        }
      end
    end

    trait :compressed_week do
      name { '35h - Semaine compressée (4 jours)' }
      weekly_hours { 35 }
      schedule_pattern do
        {
          'monday' => '08:00-17:45',
          'tuesday' => '08:00-17:45',
          'wednesday' => '08:00-17:45',
          'thursday' => '08:00-17:45'
        }
      end
    end

    trait :max_hours do
      name { '48h - Maximum légal' }
      weekly_hours { 48 }
      schedule_pattern do
        {
          'monday' => '08:00-20:00',
          'tuesday' => '08:00-20:00',
          'wednesday' => '08:00-20:00',
          'thursday' => '08:00-20:00'
        }
      end
    end
  end
end
