require "test_helper"

class BikramSambatDatedTest < ActiveSupport::TestCase
  setup { Current.shop = shops(:alpha) }
  teardown { Current.shop = nil }

  # Invoice is the simplest includer (bs_dates_for :issued_at) — exercises
  # the concern directly without depending on other models' fixtures.
  test "populates bs_year/month/day on create" do
    invoice = table_sessions(:alpha_t1_open).invoices.create!(
      shop: shops(:alpha), number: "INV/2083/84/00001", financial_year: "2083/84", sequence: 1,
      issued_at: Time.zone.local(2026, 7, 17), taxable_paise: 100, cgst_paise: 0, sgst_paise: 0, total_paise: 100
    )

    assert_equal [ 2083, 4, 1 ], [ invoice.issued_at_bs_year, invoice.issued_at_bs_month, invoice.issued_at_bs_day ]
  end

  test "recomputes bs columns when the source column changes" do
    invoice = table_sessions(:alpha_t1_open).invoices.create!(
      shop: shops(:alpha), number: "INV/2082/83/00001", financial_year: "2082/83", sequence: 1,
      issued_at: Time.zone.local(2026, 1, 1), taxable_paise: 100, cgst_paise: 0, sgst_paise: 0, total_paise: 100
    )

    invoice.update!(issued_at: Time.zone.local(2026, 7, 17))

    assert_equal [ 2083, 4, 1 ], [ invoice.issued_at_bs_year, invoice.issued_at_bs_month, invoice.issued_at_bs_day ]
  end

  # TicketItem's voided_at is nullable and unset until void! — the
  # nil-safe branch (`value && BikramSambat.from_gregorian(...)`).
  test "leaves bs columns nil when the source date is nil" do
    ticket = table_sessions(:alpha_t1_open).tickets.create!(
      client_token: SecureRandom.uuid, number: 1, placed_at: Time.current,
      placed_by: users(:alpha_waiter), status: "pending"
    )
    item = ticket.ticket_items.create!(menu_item: menu_items(:alpha_dosa), quantity: 1)

    assert_nil item.voided_at_bs_year

    item.void!(reason: "test", by: users(:alpha_waiter))

    assert item.voided_at_bs_year.present?
  end
end
