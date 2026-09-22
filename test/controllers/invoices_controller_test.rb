require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Current.shop = shops(:alpha)
    sign_in_as(users(:alpha_waiter), pin: "2222")
  end
  teardown { Current.reset }

  test "reprint bumps print_count and redirects to the bill" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    invoice = Billing.issue_invoice!(table_session: session)

    post reprint_invoice_url(invoice)

    assert_redirected_to table_session_bill_path(session)
    assert_equal 1, invoice.reload.print_count
  end
end
