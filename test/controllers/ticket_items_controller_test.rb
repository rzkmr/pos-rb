require "test_helper"

class TicketItemsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "void requires a reason and writes an audit_event, dropping the total" do
    session = table_sessions(:alpha_t1_open)
    ticket = Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 2 } ]
    )
    item = ticket.ticket_items.first
    subtotal_before = session.subtotal_paisa

    assert_difference "AuditEvent.count", 1 do
      patch void_ticket_item_url(item), params: { reason: "Wrong order" }
    end

    item.reload
    assert item.voided_at.present?
    assert_equal "Wrong order", item.void_reason
    assert session.subtotal_paisa < subtotal_before
  end
end
