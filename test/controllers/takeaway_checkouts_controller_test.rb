require "test_helper"

class TakeawayCheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Current.shop = shops(:alpha)
    sign_in_as(users(:alpha_waiter), pin: "2222")
    @counter = shops(:alpha).dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    @table_session = @counter.table_sessions.create!(opened_by: users(:alpha_waiter), opened_at: Time.current, status: "open")
  end
  teardown { Current.reset }

  test "submits the ticket, pays the exact total, issues the invoice, and settles the session" do
    assert_difference [ "Ticket.count", "Payment.count", "Invoice.count" ], 1 do
      post takeaway_checkouts_url, params: {
        client_token: SecureRandom.uuid,
        table_session_id: @table_session.id,
        method: "cash",
        items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 2 } ]
      }, as: :json
    end

    assert_response :created
    @table_session.reload
    assert_equal "paid", @table_session.status
    assert_equal @table_session.invoices.last.gross_paisa, @table_session.paid_paisa
  end

  test "retrying with the same client_token does not double-charge" do
    token = SecureRandom.uuid
    params = {
      client_token: token,
      table_session_id: @table_session.id,
      method: "cash",
      items: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    }

    post takeaway_checkouts_url, params: params, as: :json
    assert_response :created

    assert_no_difference [ "Ticket.count", "Payment.count", "Invoice.count" ] do
      post takeaway_checkouts_url, params: params, as: :json
    end

    assert_equal 1, @table_session.reload.payments.count
  end
end
