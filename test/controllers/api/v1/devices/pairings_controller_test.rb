require "test_helper"

class Api::V1::Devices::PairingsControllerTest < ActionDispatch::IntegrationTest
  test "pairs a device and returns a bearer token" do
    assert_difference -> { shops(:alpha).devices.count }, 1 do
      post api_v1_devices_pair_url, params: { pairing_pin: "9999", label: "Cashier 1" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["token"].present?
    assert_equal "Cashier 1", body["device"]["label"]

    device = Device.find(body["device"]["id"])
    assert device.authenticate_token(body["token"])
  end

  test "defaults the label when none given" do
    post api_v1_devices_pair_url, params: { pairing_pin: "9999" }

    assert_response :created
    assert JSON.parse(response.body)["device"]["label"].present?
  end

  test "401s with wrong pairing pin and does not create a device" do
    assert_no_difference -> { shops(:alpha).devices.count } do
      post api_v1_devices_pair_url, params: { pairing_pin: "0000", label: "Cashier 1" }
    end

    assert_response :unauthorized
    assert_equal "invalid_pairing_pin", JSON.parse(response.body)["error"]
  end

  test "locks out after repeated failures shop-wide" do
    8.times { post api_v1_devices_pair_url, params: { pairing_pin: "0000" } }

    post api_v1_devices_pair_url, params: { pairing_pin: "9999" }

    assert_response :too_many_requests
    assert_equal "pairing_locked", JSON.parse(response.body)["error"]
  end
end
