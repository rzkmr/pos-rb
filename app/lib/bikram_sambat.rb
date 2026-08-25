# BS↔AD conversion backed by config/data/bikram_sambat.yml — CLAUDE.md
# invariant #8: a lookup table, never a formula (BS month lengths follow
# the actual solar transit, not a fixed rule, so no formula is accurate
# across years). See that file for sourcing and verification notes.
#
# Nepal's fiscal year runs Shrawan 1 (BS month 4, day 1) to the last day
# of the following Ashad (BS month 3) — not 1 April, not 1 January
# (CLAUDE.md invariant #8). fiscal_year_for expresses that as "2082/83"
# (the calendar year Shrawan 1 falls in, plus the next BS year's last two
# digits), matching API-SPEC.md's fiscal_year_bs examples.
class BikramSambat
  DATA_PATH = Rails.root.join("config/data/bikram_sambat.yml")
  MONTH_NAMES_NE = %w[बैशाख जेठ असार साउन भदौ असोज कार्तिक मंसिर पुष माघ फागुन चैत].freeze
  SHRAWAN_MONTH = 4 # 1-indexed BS month: Baisakh=1, Jestha=2, Ashad=3, Shrawan=4

  UnknownYear = Class.new(StandardError)

  Date_ = Struct.new(:year, :month, :day) do
    def to_s
      format("%04d-%02d-%02d", year, month, day)
    end
  end

  class << self
    # Converts a Gregorian date to its BS calendar equivalent.
    def from_gregorian(gregorian_date)
      gregorian_date = gregorian_date.to_date
      year = year_containing(gregorian_date)
      entry = years.fetch(year)
      day_offset = (gregorian_date - entry.fetch(:baisakh_1)).to_i

      month = 0
      remaining = day_offset
      entry.fetch(:month_days).each_with_index do |days_in_month, index|
        if remaining < days_in_month
          month = index + 1
          break
        end
        remaining -= days_in_month
      end

      Date_.new(year, month, remaining + 1)
    end

    # Converts a BS calendar date back to Gregorian.
    def to_gregorian(year, month, day)
      entry = years.fetch(year) { raise UnknownYear, "no BS calendar data for year #{year}" }
      raise ArgumentError, "month must be 1..12, got #{month}" unless (1..12).cover?(month)

      days_before_month = entry.fetch(:month_days).first(month - 1).sum
      entry.fetch(:baisakh_1) + days_before_month + (day - 1)
    end

    # "2082/83" — the fiscal year the given Gregorian date falls in.
    # Shrawan 1 of BS year Y through Ashad-end of BS year Y+1.
    def fiscal_year_for(gregorian_date)
      bs = from_gregorian(gregorian_date)
      fiscal_start_year = bs.month >= SHRAWAN_MONTH ? bs.year : bs.year - 1
      format("%d/%02d", fiscal_start_year, (fiscal_start_year + 1) % 100)
    end

    # The Gregorian date Shrawan 1 falls on for the fiscal year starting
    # in BS year `fiscal_start_year`. Used to detect rollover boundaries
    # in tests and by anything that needs to know "when does this fiscal
    # year begin" without going through a specific transaction date.
    def shrawan_1(fiscal_start_year)
      to_gregorian(fiscal_start_year, SHRAWAN_MONTH, 1)
    end

    def last_supported_year
      years.keys.max
    end

    def first_supported_year
      years.keys.min
    end

    private

    def year_containing(gregorian_date)
      candidate = years.keys.select { |year| years.fetch(year).fetch(:baisakh_1) <= gregorian_date }.max
      unless candidate
        raise UnknownYear, "#{gregorian_date} is before the earliest supported BS year (#{first_supported_year})"
      end

      entry = years.fetch(candidate)
      year_end = entry.fetch(:baisakh_1) + entry.fetch(:month_days).sum
      if gregorian_date >= year_end && candidate == last_supported_year
        raise UnknownYear, "#{gregorian_date} is beyond the last supported BS year (#{last_supported_year}) — extend config/data/bikram_sambat.yml"
      end

      candidate
    end

    def years
      @years ||= YAML.unsafe_load_file(DATA_PATH).fetch("years").transform_values do |entry|
        { baisakh_1: entry.fetch("baisakh_1"), month_days: entry.fetch("month_days") }
      end
    end
  end
end
