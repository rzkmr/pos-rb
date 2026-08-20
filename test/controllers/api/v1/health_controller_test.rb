require "test_helper"

class Api::V1::HealthControllerTest < ActionDispatch::IntegrationTest
  test "returns ok with no auth required" do
    get api_v1_health_url

    assert_response :success
    body = JSON.parse(response.body)
    assert body["ok"]
    assert body["server_time"]
  end
end
