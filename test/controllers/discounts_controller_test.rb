require "test_helper"

class DiscountsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "applying a discount writes an audit_event and reduces the subtotal" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    subtotal_before = session.subtotal_paisa

    assert_difference "AuditEvent.count", 1 do
      post table_session_discount_url(session), params: { amount_paisa: 1000, reason: "Loyal customer" }
    end

    session.reload
    assert_equal 1000, session.discount_paisa
    assert_equal subtotal_before - 1000, session.subtotal_paisa
  end
end
