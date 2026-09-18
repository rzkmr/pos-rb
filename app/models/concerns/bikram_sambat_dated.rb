# Keeps a BS (year, month, day) sidecar in sync with a Gregorian
# datetime/date column, so reports and searches that filter by BS fiscal
# year or BS calendar day (invoice register, till reconciliation, audit
# trail, void/reprint reports) can query indexed integer columns directly
# instead of converting every row through BikramSambat.from_gregorian at
# read time — see CLAUDE.md invariant #8.
#
# The Gregorian column stays the single source of truth; the BS columns
# are derived and rewritten whenever it changes. Usage:
#
#   class Invoice < ApplicationRecord
#     bs_dates_for :issued_at
#   end
#
# expects issued_at_bs_year/_bs_month/_bs_day columns (see migration).
module BikramSambatDated
  extend ActiveSupport::Concern

  class_methods do
    def bs_dates_for(*fields)
      fields.each do |field|
        before_save do
          next unless new_record? || attribute_changed?(field.to_s)

          value = send(field)
          bs = value && BikramSambat.from_gregorian(value.to_date)
          send("#{field}_bs_year=", bs&.year)
          send("#{field}_bs_month=", bs&.month)
          send("#{field}_bs_day=", bs&.day)
        end
      end
    end
  end
end
