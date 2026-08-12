require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "split payment across cash and UPI settles the session and issues one invoice" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    billing = Billing.compute(shop: shops(:alpha), taxable_paise: session.subtotal_paise)
    half = billing.total_paise / 2

    post table_session_payments_url(session), params: { payment: { method: "cash", amount_paise: half } }
    post table_session_payments_url(session), params: { payment: { method: "upi", amount_paise: billing.total_paise - half, reference: "upi-ref-1" } }

    session.reload
    assert_equal "paid", session.status
    assert_equal 1, session.invoices.count
    assert_equal billing.total_paise, session.invoices.first.total_paise
  end

  test "partial payment does not close the session" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    post table_session_payments_url(session), params: { payment: { method: "cash", amount_paise: 100 } }

    assert_equal "open", session.reload.status
  end
end
