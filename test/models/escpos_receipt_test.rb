require "test_helper"

class EscposReceiptTest < ActiveSupport::TestCase
  test "build includes invoice number, totals, and no DUPLICATE marker by default" do
    invoice = build_invoice

    bytes = EscposReceipt.build(invoice: invoice)

    assert_includes bytes, invoice.number
    assert_not_includes bytes, "DUPLICATE"
  end

  test "build with duplicate: true includes the DUPLICATE marker" do
    invoice = build_invoice

    bytes = EscposReceipt.build(invoice: invoice, duplicate: true)

    assert_includes bytes, "DUPLICATE"
  end

  test "build shows service charge and VAT lines" do
    invoice = build_invoice

    bytes = EscposReceipt.build(invoice: invoice)

    assert_includes bytes, "Service Charge"
    assert_includes bytes, "VAT"
  end

  private

  def build_invoice
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    Billing.issue_invoice!(table_session: session)
  end
end
