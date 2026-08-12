require "test_helper"

class BillingTest < ActiveSupport::TestCase
  test "compute splits GST evenly into CGST and SGST on the subtotal" do
    shop = shops(:alpha)

    result = Billing.compute(shop: shop, taxable_paise: 100_00)

    assert_equal 100_00, result.taxable_paise
    assert_equal 250, result.cgst_paise
    assert_equal 250, result.sgst_paise
  end

  test "compute rounds the total to the nearest rupee and records round_off" do
    shop = shops(:alpha)

    result = Billing.compute(shop: shop, taxable_paise: 99)

    total_before_round = result.taxable_paise + result.cgst_paise + result.sgst_paise
    assert_equal result.total_paise, total_before_round + result.round_off_paise
    assert_equal 0, result.total_paise % 100
  end

  test "compute charges no tax under composition scheme" do
    shop = shops(:alpha)
    shop.update!(composition_scheme: true)

    result = Billing.compute(shop: shop, taxable_paise: 100_00)

    assert_equal 0, result.cgst_paise
    assert_equal 0, result.sgst_paise
    assert_equal 100_00, result.total_paise
  end

  test "issue_invoice! assigns a gapless sequential number for the financial year" do
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
