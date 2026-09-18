# Adds BS (year, month, day) sidecar columns for every business-event
# date that reports/search filter by fiscal year or BS calendar day —
# see BikramSambatDated and CLAUDE.md invariant #8. Plain config/audit
# timestamps (created_at on shops, menu_items, users, etc.) are left
# Gregorian-only; nothing queries those by BS.
class AddBikramSambatDates < ActiveRecord::Migration[8.1]
  TARGETS = {
    invoices: :issued_at,
    table_sessions: [ :opened_at, :closed_at ],
    tickets: :placed_at,
    payments: :created_at,
    audit_events: :created_at,
    print_jobs: :created_at,
    ticket_items: :voided_at
  }.freeze

  def change
    TARGETS.each do |table, fields|
      Array(fields).each do |field|
        add_column table, "#{field}_bs_year", :integer
        add_column table, "#{field}_bs_month", :integer
        add_column table, "#{field}_bs_day", :integer
        add_index table, [ "#{field}_bs_year", "#{field}_bs_month", "#{field}_bs_day" ],
                  name: "index_#{table}_on_#{field}_bs_date"
      end
    end
  end
end
