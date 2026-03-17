# frozen_string_literal: true

# Computes French public holidays and working days.
# Handles the Computus algorithm for Easter-based holidays.
# Supports Alsace-Moselle region (depts 57, 67, 68) which has 2 extra holidays:
#   - Good Friday (Vendredi Saint)
#   - St. Stephen's Day (26 décembre)
class FrenchCalendar
  ALSACE_MOSELLE_DEPARTMENTS = %w[57 67 68].freeze

  def initialize(region: nil)
    @alsace_moselle = region == :alsace_moselle
  end

  def working_days_between(start_date, end_date)
    days = 0
    current = start_date
    while current <= end_date
      days += 1 unless weekend?(current) || holiday?(current)
      current += 1.day
    end
    days
  end

  def holiday?(date)
    holidays_for_year(date.year).include?(date)
  end

  def alsace_moselle?
    @alsace_moselle
  end

  private

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  def holidays_for_year(year)
    days = [
      Date.new(year, 1, 1),
      easter_monday(year),
      Date.new(year, 5, 1),
      Date.new(year, 5, 8),
      ascension_day(year),
      whit_monday(year),
      Date.new(year, 7, 14),
      Date.new(year, 8, 15),
      Date.new(year, 11, 1),
      Date.new(year, 11, 11),
      Date.new(year, 12, 25)
    ]

    if @alsace_moselle
      days << good_friday(year)        # Vendredi Saint
      days << Date.new(year, 12, 26)   # Saint-Étienne
    end

    days
  end

  def easter_sunday(year)
    a = year % 19
    b = year / 100
    c = year % 100
    d = b / 4
    e = b % 4
    f = (b + 8) / 25
    g = (b - f + 1) / 3
    h = (19 * a + b - d - g + 15) % 30
    i = c / 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) / 451
    month = (h + l - 7 * m + 114) / 31
    day   = ((h + l - 7 * m + 114) % 31) + 1
    Date.new(year, month, day)
  end

  def easter_monday(year)  = easter_sunday(year) + 1.day
  def good_friday(year)    = easter_sunday(year) - 2.days
  def ascension_day(year)  = easter_sunday(year) + 39.days
  def whit_monday(year)    = easter_sunday(year) + 50.days
end
