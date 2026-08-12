require "test_helper"

class BillsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "show renders the subtotal and GST breakdown" do
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 2 } ]
    )

    get table_session_bill_url(session)

    assert_response :success
  end
end
