require "test_helper"

class Api::V1::DeltaControllerTest < ActionDispatch::IntegrationTest
  setup { @headers = api_headers_for(shop: shops(:alpha)) }

  test "returns changes since cursor" do
    starting_cursor = shops(:alpha).reload.api_sync_cursor

    menu_item = MenuItem.create!(shop: shops(:alpha), name: "Chai", category: "beverage", gross_price_paisa: 2000)

    get api_v1_delta_url, params: { cursor: starting_cursor }, headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal false, body["has_more"]
    upsert = body["changes"].find { |c| c["entity"] == "menu_item" && c["record"]["id"] == menu_item.id }
    assert upsert
    assert_equal "upsert", upsert["action"]
    assert_equal "Chai", upsert["record"]["name"]
  end

  test "delete emits a tombstone" do
    menu_item = MenuItem.create!(shop: shops(:alpha), name: "Chai", category: "beverage", gross_price_paisa: 2000)
    starting_cursor = shops(:alpha).reload.api_sync_cursor

    menu_item.destroy!

    get api_v1_delta_url, params: { cursor: starting_cursor }, headers: @headers

    body = JSON.parse(response.body)
    tombstone = body["changes"].find { |c| c["entity"] == "menu_item" && c["record"]["id"] == menu_item.id }
    assert_equal "delete", tombstone["action"]
  end

  test "respects limit and reports has_more" do
    3.times { |i| MenuItem.create!(shop: shops(:alpha), name: "Item #{i}", category: "side", gross_price_paisa: 1000) }

    get api_v1_delta_url, params: { cursor: 0, limit: 2 }, headers: @headers

    body = JSON.parse(response.body)
    assert_equal 2, body["changes"].size
    assert body["has_more"]
  end
end
