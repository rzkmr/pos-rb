require "test_helper"

class Sync::ActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alpha_waiter), pin: "2222")
  end

  test "applies a valid action and returns applied" do
    session = table_sessions(:alpha_t1_open)

    post sync_actions_url, params: {
      actions: [
        {
          client_action_id: "test-token-1", kind: "submit_ticket",
          payload: {
            table_session_id: session.id, client_token: "test-token-1",
            items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 2 } ]
          }
        }
      ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    result = body["results"].first
    assert_equal "applied", result["status"]
  end

  test "replaying the same client_action_id returns duplicate, applies nothing twice" do
    session = table_sessions(:alpha_t1_open)
    action = {
      client_action_id: "test-token-2", kind: "submit_ticket",
      payload: { table_session_id: session.id, client_token: "test-token-2",
                 items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ] }
    }

    assert_difference "Ticket.count", 1 do
      post sync_actions_url, params: { actions: [ action ] }, as: :json
    end

    assert_no_difference "Ticket.count" do
      post sync_actions_url, params: { actions: [ action ] }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal "duplicate", body["results"].first["status"]
  end

  test "one poison action in a batch does not stop the others from applying" do
    session = table_sessions(:alpha_t1_open)

    post sync_actions_url, params: {
      actions: [
        { client_action_id: "good-1", kind: "submit_ticket",
          payload: { table_session_id: session.id, client_token: "good-1",
                     items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ] } },
        { client_action_id: "bad-1", kind: "submit_ticket",
          payload: { table_session_id: 999_999, client_token: "bad-1", items: [] } }
      ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    statuses = body["results"].to_h { |r| [ r["client_action_id"], r["status"] ] }
    assert_equal "applied", statuses["good-1"]
    assert_equal "rejected", statuses["bad-1"]
  end

  test "an unknown kind is rejected, not a server error" do
    post sync_actions_url, params: {
      actions: [ { client_action_id: "unknown-1", kind: "not_a_real_kind", payload: {} } ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "rejected", body["results"].first["status"]
  end
end
