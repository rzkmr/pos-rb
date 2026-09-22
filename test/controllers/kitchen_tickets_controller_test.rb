require "test_helper"

class KitchenTicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Current.shop = shops(:alpha)
    sign_in_as(users(:alpha_waiter), pin: "2222")
  end
  teardown { Current.reset }

  test "index lists tickets that are not yet served" do
    session = table_sessions(:alpha_t1_open)
    ticket = Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    get kitchen_tickets_url

    assert_response :success
    assert_match "Ticket ##{ticket.number}", response.body
  end

  test "update advances ticket status" do
    session = table_sessions(:alpha_t1_open)
    ticket = Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    patch kitchen_ticket_url(ticket), params: { status: "preparing" }

    assert_redirected_to kitchen_tickets_path
    assert_equal "preparing", ticket.reload.status
  end

  test "index excludes served tickets" do
    session = table_sessions(:alpha_t1_open)
    ticket = Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    ticket.update!(status: "served")

    get kitchen_tickets_url

    assert_response :success
    assert_no_match "Ticket ##{ticket.number}", response.body
  end
end
