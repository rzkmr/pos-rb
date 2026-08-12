require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "create submits a ticket with items" do
    session = table_sessions(:alpha_t1_open)

    assert_difference "Ticket.count", 1 do
      post tickets_url, params: {
        client_token: SecureRandom.uuid,
        table_session_id: session.id,
        items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 2 } ]
      }, as: :json
    end

    assert_response :created
  end

  test "create with a duplicate client_token does not create a second ticket" do
    session = table_sessions(:alpha_t1_open)
    token = SecureRandom.uuid
    params = {
      client_token: token,
      table_session_id: session.id,
      items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    }

    post tickets_url, params: params, as: :json
    first_id = JSON.parse(response.body)["id"]

    assert_no_difference "Ticket.count" do
      post tickets_url, params: params, as: :json
    end

    assert_equal first_id, JSON.parse(response.body)["id"]
  end

  test "two separate tickets on one session both persist with distinct numbers" do
    session = table_sessions(:alpha_t1_open)

    post tickets_url, params: {
      client_token: SecureRandom.uuid,
      table_session_id: session.id,
      items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    }, as: :json

    post tickets_url, params: {
      client_token: SecureRandom.uuid,
      table_session_id: session.id,
      items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 3 } ]
    }, as: :json

    assert_equal [ 1, 2 ], session.tickets.order(:number).pluck(:number)
  end
end
