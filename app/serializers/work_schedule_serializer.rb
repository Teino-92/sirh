# frozen_string_literal: true

class WorkScheduleSerializer
  def initialize(schedule)
    @schedule = schedule
  end

  def as_json
    {
      id:               @schedule.id,
      name:             @schedule.name,
      weekly_hours:     @schedule.weekly_hours,
      schedule_pattern: @schedule.schedule_pattern
    }
  end
end
