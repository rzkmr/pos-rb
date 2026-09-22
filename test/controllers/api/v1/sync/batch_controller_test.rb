require "test_helper"

class Api::V1::Sync::BatchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shop = shops(:alpha)
    Current.shop = @shop
    @headers = api_headers_for(shop: @shop)
    @user = users(:alpha_waiter)
    @table_session = table_sessions(:alpha_t1_open)
  end
  teardown { Current.reset }

  test "ticket.create is accepted and idempotent on retry with the same op_id" do
    op_id = SecureRandom.uuid
    operation = {
      op_id: op_id,
      type: "ticket.create",
      acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: {
        table_session_id: @table_session.id,
        client_token: SecureRandom.uuid,
        items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 2 } ]
      }
    }

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json
    assert_response :success
    first = JSON.parse(response.body)["results"].first
    assert_equal "accepted", first["status"]
    assert_equal 1, @table_session.tickets.count

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json
    second = JSON.parse(response.body)["results"].first
    assert_equal "duplicate", second["status"]
    assert_equal 1, @table_session.tickets.count
  end

  test "an unknown type is rejected, non-retryable, and does not block the rest of the batch" do
    good = {
      op_id: SecureRandom.uuid, type: "ticket.create", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { table_session_id: @table_session.id, client_token: SecureRandom.uuid,
                 items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ] }
    }
    bad = { op_id: SecureRandom.uuid, type: "not_a_real_type", acting_user_id: @user.id, occurred_at: Time.current.iso8601, payload: {} }

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ bad, good ] }, headers: @headers, as: :json

    results = JSON.parse(response.body)["results"]
    assert_equal "rejected", results[0]["status"]
    assert_equal false, results[0]["retryable"]
    assert_equal "accepted", results[1]["status"]
  end

  test "ticket_item.void without a reason is rejected" do
    ticket = Ticket.submit!(
      table_session: @table_session, client_token: SecureRandom.uuid, placed_by: @user,
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    operation = {
      op_id: SecureRandom.uuid, type: "ticket_item.void", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { ticket_item_id: ticket.ticket_items.first.id }
    }

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json

    result = JSON.parse(response.body)["results"].first
    assert_equal "rejected", result["status"]
    refute ticket.ticket_items.first.reload.voided_at
  end

  test "invoice.issue rejects a client total that disagrees with server tax computation" do
    Ticket.submit!(
      table_session: @table_session, client_token: SecureRandom.uuid, placed_by: @user,
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    operation = {
      op_id: SecureRandom.uuid, type: "invoice.issue", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { table_session_id: @table_session.id, gross_paisa: 1 }
    }

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json

    result = JSON.parse(response.body)["results"].first
    assert_equal "rejected", result["status"]
    assert_match(/tax_mismatch/, result["message"])
    assert_equal 0, @table_session.invoices.count
  end

  test "reports clock_skew_seconds from device_time" do
    skewed_time = 10.minutes.ago.iso8601

    post api_v1_sync_batch_url, params: { device_time: skewed_time, operations: [] }, headers: @headers, as: :json

    body = JSON.parse(response.body)
    assert_in_delta 600, body["clock_skew_seconds"], 5
  end

  test "401s with no bearer token" do
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [] }, as: :json

    assert_response :unauthorized
  end
end
