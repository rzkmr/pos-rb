require "test_helper"

class BillingTest < ActiveSupport::TestCase
  test "compute extracts VAT first, then service charge from the residual" do
    shop = shops(:alpha) # vat_rate_bp: 1300, service_charge_rate_bp: 1000

    result = Billing.compute(shop: shop, gross_paisa: 100_00)

    taxable_before_vat = result.gross_paisa - result.vat_paisa
    assert_equal taxable_before_vat, result.base_paisa + result.service_charge_paisa
  end

  # CLAUDE.md invariant #3 / testing expectation #5: base + service_charge +
  # vat == gross exactly, in paisa, across a range of totals — residuals
  # guarantee this, never independent rounding of each component.
  test "base + service_charge + vat sums exactly to gross across a range of totals" do
    shop = shops(:alpha)

    (1..500).each do |rupees|
      gross_paisa = rupees * 137 # odd multiplier to avoid only-round-number totals
      result = Billing.compute(shop: shop, gross_paisa: gross_paisa)

      assert_equal gross_paisa, result.base_paisa + result.service_charge_paisa + result.vat_paisa,
        "mismatch at gross_paisa=#{gross_paisa}"
    end
  end

  test "compute never adds tax on top — menu prices are already gross" do
    shop = shops(:alpha)

    result = Billing.compute(shop: shop, gross_paisa: 100_00)

    assert_equal 100_00, result.gross_paisa
  end

  test "issue_invoice! assigns a gapless sequential number for the BS financial year" do
    shop = shops(:alpha)
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    invoice = Billing.issue_invoice!(table_session: session)

    assert_equal 1, invoice.sequence
    assert_equal "INV/#{shop.reload.invoice_fy}/00001", invoice.number
  end
end
