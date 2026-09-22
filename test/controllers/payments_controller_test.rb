require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Current.shop = shops(:alpha)
    sign_in_as(users(:alpha_waiter), pin: "2222")
  end
  teardown { Current.reset }

  test "split payment across cash and Fonepay settles the session and issues one invoice" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    billing = Billing.compute(shop: shops(:alpha), gross_paisa: session.subtotal_paisa)
    half = billing.gross_paisa / 2

    post table_session_payments_url(session), params: { payment: { method: "cash", amount_paisa: half } }
    post table_session_payments_url(session), params: { payment: { method: "fonepay", amount_paisa: billing.gross_paisa - half, reference: "fonepay-ref-1" } }

    session.reload
    assert_equal "paid", session.status
    assert_equal 1, session.invoices.count
    assert_equal billing.gross_paisa, session.invoices.first.gross_paisa
  end

  test "partial payment does not close the session" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    post table_session_payments_url(session), params: { payment: { method: "cash", amount_paisa: 100 } }

    assert_equal "open", session.reload.status
  end
end
