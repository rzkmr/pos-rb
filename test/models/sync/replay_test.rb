require "test_helper"

class Sync::ReplayTest < ActiveSupport::TestCase
  setup do
    Current.shop = shops(:alpha)
    Current.user = users(:alpha_waiter)
  end

  teardown { Current.reset }

  test "record_payment is idempotent — a replay does not double-credit the session" do
    session = table_sessions(:alpha_t1_open)
    dosa = menu_items(:alpha_dosa)
    Ticket.submit!(table_session: session, client_token: SecureRandom.uuid, placed_by: users(:alpha_waiter),
                    items_attributes: [ { menu_item_id: dosa.id, quantity: 1 } ])
    billing = Billing.compute(shop: shops(:alpha), gross_paisa: session.reload.subtotal_paisa)

    payload = {
      "table_session_id" => session.id, "method" => "cash",
      "amount_paisa" => billing.gross_paisa, "client_token" => "pay-token-1"
    }

    assert_difference "Payment.count", 1 do
      Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                         client_action_id: "pay-1", kind: "record_payment", payload: payload)
    end

    assert_no_difference "Payment.count" do
      result = Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                                  client_action_id: "pay-1", kind: "record_payment", payload: payload)
      assert_equal "duplicate", result[:status]
    end
  end

  test "void_ticket_item replay does not write a second audit_event" do
    session = table_sessions(:alpha_t1_open)
    dosa = menu_items(:alpha_dosa)
    ticket = Ticket.submit!(table_session: session, client_token: SecureRandom.uuid, placed_by: users(:alpha_waiter),
                             items_attributes: [ { menu_item_id: dosa.id, quantity: 1 } ])
    ticket_item = ticket.ticket_items.first
    payload = { "ticket_item_id" => ticket_item.id, "reason" => "wrong item" }

    assert_difference "AuditEvent.where(action: 'void_ticket_item').count", 1 do
      Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                         client_action_id: "void-1", kind: "void_ticket_item", payload: payload)
    end

    assert_no_difference "AuditEvent.where(action: 'void_ticket_item').count" do
      result = Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                                  client_action_id: "void-1", kind: "void_ticket_item", payload: payload)
      assert_equal "duplicate", result[:status]
    end
  end

  test "update_ticket_status rejects a stale backwards transition" do
    session = table_sessions(:alpha_t1_open)
    dosa = menu_items(:alpha_dosa)
    ticket = Ticket.submit!(table_session: session, client_token: SecureRandom.uuid, placed_by: users(:alpha_waiter),
                             items_attributes: [ { menu_item_id: dosa.id, quantity: 1 } ])
    ticket.update!(status: "ready")

    result = Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                                client_action_id: "status-1", kind: "update_ticket_status",
                                payload: { "ticket_id" => ticket.id, "status" => "preparing" })

    assert_equal "rejected", result[:status]
    assert_equal "ready", ticket.reload.status
  end

  test "a nonexistent record reference is rejected, not a server error" do
    result = Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                                client_action_id: "missing-1", kind: "record_payment",
                                payload: { "table_session_id" => 999_999, "method" => "cash",
                                           "amount_paisa" => 100, "client_token" => "x" })

    assert_equal "rejected", result[:status]
  end

  test "an unknown kind is rejected without raising" do
    result = Sync::Replay.call(shop: shops(:alpha), device: nil, user: users(:alpha_waiter),
                                client_action_id: "unknown-1", kind: "not_a_real_kind", payload: {})

    assert_equal "rejected", result[:status]
  end

  test "takeaway_checkout works from a cold start: no existing session, no signed-in user" do
    shop = shops(:alpha)
    shop.dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    dosa = menu_items(:alpha_dosa)
    token = SecureRandom.uuid

    result = Sync::Replay.call(
      shop: shop, device: nil, user: nil, client_action_id: "cold-1", kind: "takeaway_checkout",
      payload: {
        "client_session_token" => token, "acting_user_id" => users(:alpha_waiter).id,
        "method" => "cash", "client_token" => "cold-1",
        "items" => [ { "menu_item_id" => dosa.id, "quantity" => 2 } ]
      }
    )

    assert_equal "applied", result[:status]
    session = TableSession.find_by(client_session_token: token)
    assert session.present?
    assert_equal users(:alpha_waiter), session.opened_by
    assert_equal 1, session.payments.count
  end

  test "takeaway_checkout is rejected when there's no signed-in user and no acting_user_id" do
    shop = shops(:alpha)
    shop.dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    dosa = menu_items(:alpha_dosa)

    result = Sync::Replay.call(
      shop: shop, device: nil, user: nil, client_action_id: "cold-2", kind: "takeaway_checkout",
      payload: {
        "client_session_token" => SecureRandom.uuid, "method" => "cash", "client_token" => "cold-2",
        "items" => [ { "menu_item_id" => dosa.id, "quantity" => 1 } ]
      }
    )

    assert_equal "rejected", result[:status]
  end
end
