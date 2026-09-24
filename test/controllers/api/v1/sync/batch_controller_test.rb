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

  test "table_session.open returns the server's real integer id, distinct from the client's payload id" do
    client_token = SecureRandom.uuid
    operation = {
      op_id: SecureRandom.uuid, type: "table_session.open", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { id: SecureRandom.uuid, client_token: client_token, dining_table_id: @shop.dining_tables.create!(label: SecureRandom.uuid, seats: 2).id, guest_count: 2 }
    }

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json

    result = JSON.parse(response.body)["results"].first
    assert_equal "accepted", result["status"]
    server_table_session_id = result.dig("server_values", "table_session_id")
    refute_nil server_table_session_id
    assert_kind_of Integer, server_table_session_id
    assert_not_equal operation[:payload][:id], server_table_session_id.to_s
  end

  test "a follow-up op using the server's real table_session_id from table_session.open succeeds" do
    open_op_id = SecureRandom.uuid
    open_operation = {
      op_id: open_op_id, type: "table_session.open", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { id: SecureRandom.uuid, client_token: SecureRandom.uuid, dining_table_id: @shop.dining_tables.create!(label: SecureRandom.uuid, seats: 2).id, guest_count: 1 }
    }
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ open_operation ] }, headers: @headers, as: :json
    open_result = JSON.parse(response.body)["results"].first
    real_table_session_id = open_result.dig("server_values", "table_session_id")

    ticket_op = {
      op_id: SecureRandom.uuid, type: "ticket.create", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { table_session_id: real_table_session_id, client_token: SecureRandom.uuid,
                 items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ] }
    }
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ ticket_op ] }, headers: @headers, as: :json

    ticket_result = JSON.parse(response.body)["results"].first
    assert_equal "accepted", ticket_result["status"]
  end

  test "a client_token reused under a different op_id resolves to the same session, not a second one" do
    # A device retrying table_session.open with a *new* op_id (its own crash/restart, not a
    # replayed request) must still land on the same table_session — the client_token is what
    # TableSession.resolve_or_open! keys off, independent of Sync::Replay's own op_id-based
    # client_actions ledger (which would only recognize an identical op_id as "duplicate").
    client_token = SecureRandom.uuid
    operation = {
      op_id: SecureRandom.uuid, type: "table_session.open", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { id: SecureRandom.uuid, client_token: client_token, dining_table_id: @shop.dining_tables.create!(label: SecureRandom.uuid, seats: 2).id, guest_count: 1 }
    }
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json
    first_id = JSON.parse(response.body)["results"].first.dig("server_values", "table_session_id")

    retried_operation = operation.merge(op_id: SecureRandom.uuid)
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ retried_operation ] }, headers: @headers, as: :json
    second_result = JSON.parse(response.body)["results"].first

    assert_equal "accepted", second_result["status"]
    assert_equal first_id, second_result.dig("server_values", "table_session_id")
    assert_equal 1, TableSession.where(client_session_token: client_token).count
  end

  test "invoice.print records a device print without enqueuing a server print job" do
    Ticket.submit!(
      table_session: @table_session, client_token: SecureRandom.uuid, placed_by: @user,
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    invoice = Billing.issue_invoice!(table_session: @table_session)

    operation = {
      op_id: SecureRandom.uuid, type: "invoice.print", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { invoice_id: invoice.id }
    }

    assert_no_enqueued_jobs do
      post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json
    end

    result = JSON.parse(response.body)["results"].first
    assert_equal "accepted", result["status"]
    assert_equal 1, invoice.reload.print_count
    assert AuditEvent.exists?(action: "device_print_invoice", subject: invoice)
  end

  test "invoice.print is idempotent on retry with the same op_id" do
    Ticket.submit!(
      table_session: @table_session, client_token: SecureRandom.uuid, placed_by: @user,
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    invoice = Billing.issue_invoice!(table_session: @table_session)

    operation = {
      op_id: SecureRandom.uuid, type: "invoice.print", acting_user_id: @user.id,
      occurred_at: Time.current.iso8601,
      payload: { invoice_id: invoice.id }
    }

    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [ operation ] }, headers: @headers, as: :json

    second = JSON.parse(response.body)["results"].first
    assert_equal "duplicate", second["status"]
    assert_equal 1, invoice.reload.print_count
  end

  test "401s with no bearer token" do
    post api_v1_sync_batch_url, params: { device_time: Time.current.iso8601, operations: [] }, as: :json

    assert_response :unauthorized
  end
end
