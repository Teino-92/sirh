# frozen_string_literal: true

class TimeEntrySerializer
  def initialize(entry)
    @entry = entry
  end

  def as_json
    {
      id:               @entry.id,
      clock_in:         @entry.clock_in,
      clock_out:        @entry.clock_out,
      duration_minutes: @entry.duration_minutes,
      hours_worked:     @entry.hours_worked,
      active:           @entry.active?,
      overtime:         @entry.overtime?,
      worked_date:      @entry.worked_date,
      location:         @entry.location
    }
  end
end
