require "test_helper"

class Api::V1::UpdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Current.shop = shops(:alpha)
    @headers = api_headers_for(shop: shops(:alpha))
  end
  teardown { Current.reset }

  test "reports a ticket status change since cursor" do
    starting_cursor = shops(:alpha).reload.api_sync_cursor
    ticket = Ticket.submit!(
      table_session: table_sessions(:alpha_t1_open), client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )

    ticket.update!(status: "preparing")

    get api_v1_updates_url, params: { cursor: starting_cursor }, headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    change = body["changes"].find { |c| c["record"]["id"] == ticket.id }
    assert_equal "ticket", change["entity"]
    assert_equal "status", change["action"]
    assert_equal "preparing", change["record"]["status"]
  end

  test "does not include reference-data changes" do
    starting_cursor = shops(:alpha).reload.api_sync_cursor
    MenuItem.create!(shop: shops(:alpha), name: "Chai", category: "beverage", gross_price_paisa: 2000)

    get api_v1_updates_url, params: { cursor: starting_cursor }, headers: @headers

    body = JSON.parse(response.body)
    assert_empty body["changes"]
  end
end
