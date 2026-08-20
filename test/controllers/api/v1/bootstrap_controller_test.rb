require "test_helper"

class Api::V1::BootstrapControllerTest < ActionDispatch::IntegrationTest
  setup { @headers = api_headers_for(shop: shops(:alpha)) }

  test "returns shop, device, users, tables and menu with a cursor" do
    get api_v1_bootstrap_url, headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal shops(:alpha).name, body["shop"]["name"]
    assert_equal 0, body["cursor"]
    assert body["device"]["id"]
    assert_equal [ "Waiter" ], body["users"].map { |u| u["name"] }
    refute body["users"].first.key?("pin")
    assert_equal [ "T1" ], body["dining_tables"].map { |t| t["label"] }
    assert_equal [ "Masala Dosa" ], body["menu_items"].map { |m| m["name"] }
  end

  test "401s with no bearer token" do
    get api_v1_bootstrap_url

    assert_response :unauthorized
  end

  test "401s with an invalid bearer token" do
    get api_v1_bootstrap_url, headers: { "Authorization" => "Bearer not-a-real-token" }

    assert_response :unauthorized
  end
end
