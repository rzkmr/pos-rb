require "test_helper"

class BikramSambatTest < ActiveSupport::TestCase
  setup { Current.shop = shops(:alpha) }
  teardown { Current.reset }

  test "converts a Gregorian date to BS" do
    bs = BikramSambat.from_gregorian(Date.new(2025, 4, 14))

    assert_equal 2082, bs.year
    assert_equal 1, bs.month
    assert_equal 1, bs.day
  end

  test "round-trips BS back to the same Gregorian date" do
    [
      Date.new(2025, 4, 14),
      Date.new(2025, 7, 17),
      Date.new(2026, 4, 13),
      Date.new(2026, 7, 16),
      Date.new(2033, 4, 14)
    ].each do |gdate|
      bs = BikramSambat.from_gregorian(gdate)
      assert_equal gdate, BikramSambat.to_gregorian(bs.year, bs.month, bs.day), "round-trip failed for #{gdate}"
    end
  end

  # CLAUDE.md invariant #8 / testing expectation #7: BS↔AD conversion
  # correct at month and year boundaries — the day before and the day of
  # a BS year rollover (Baisakh 1) must land in the correct adjacent year.
  test "is correct across a BS year boundary" do
    day_before = BikramSambat.from_gregorian(Date.new(2026, 4, 13))
    rollover_day = BikramSambat.from_gregorian(Date.new(2026, 4, 14))

    assert_equal [ 2082, 12, 30 ], [ day_before.year, day_before.month, day_before.day ]
    assert_equal [ 2083, 1, 1 ], [ rollover_day.year, rollover_day.month, rollover_day.day ]
  end

  # CLAUDE.md invariant #8 / testing expectation #6: boundary tests at
  # Shrawan 1 are mandatory — a wrong boundary corrupts invoice numbering.
  test "fiscal_year_for is correct exactly at a Shrawan 1 boundary" do
    last_day_of_old_fy = Date.new(2026, 7, 16) # Ashad end 2083
    shrawan_1 = Date.new(2026, 7, 17)          # Shrawan 1 2083 — new FY starts

    assert_equal "2082/83", BikramSambat.fiscal_year_for(last_day_of_old_fy)
    assert_equal "2083/84", BikramSambat.fiscal_year_for(shrawan_1)
  end

  test "fiscal_year_for is stable across the rest of a fiscal year" do
    assert_equal "2082/83", BikramSambat.fiscal_year_for(Date.new(2025, 7, 17)) # Shrawan 1 2082
    assert_equal "2082/83", BikramSambat.fiscal_year_for(Date.new(2025, 12, 1))
    assert_equal "2082/83", BikramSambat.fiscal_year_for(Date.new(2026, 4, 14)) # Baisakh 1 2083 — still same FY
    assert_equal "2082/83", BikramSambat.fiscal_year_for(Date.new(2026, 7, 16)) # Ashad end 2083 — last day
  end

  test "shrawan_1 returns the Gregorian date the fiscal year starts on" do
    assert_equal Date.new(2026, 7, 17), BikramSambat.shrawan_1(2083)
  end

  test "raises UnknownYear before the earliest supported year" do
    assert_raises(BikramSambat::UnknownYear) { BikramSambat.from_gregorian(Date.new(2017, 1, 1)) }
  end

  test "raises UnknownYear beyond the last supported year" do
    assert_raises(BikramSambat::UnknownYear) { BikramSambat.from_gregorian(Date.new(2040, 1, 1)) }
  end

  test "every supported year's Baisakh 1 is consistent with the previous year's day count" do
    (BikramSambat.first_supported_year...BikramSambat.last_supported_year).each do |year|
      this_year_start = BikramSambat.to_gregorian(year, 1, 1)
      next_year_start = BikramSambat.to_gregorian(year + 1, 1, 1)
      days_in_year = (next_year_start - this_year_start).to_i

      assert_includes 365..366, days_in_year, "BS #{year} has an implausible day count: #{days_in_year}"
    end
  end
end
