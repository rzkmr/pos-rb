require "test_helper"

class Api::V1::Owner::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "returns owner identity for valid credentials" do
    post api_v1_owner_login_url, params: { username: "admin", password: "supersecret1" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal admin_users(:alpha_admin).id, body["owner"]["id"]
    assert_equal "admin", body["owner"]["username"]
  end

  test "401s with wrong password" do
    post api_v1_owner_login_url, params: { username: "admin", password: "wrong" }

    assert_response :unauthorized
    assert_equal "invalid_credentials", JSON.parse(response.body)["error"]
  end

  test "401s with unknown username" do
    post api_v1_owner_login_url, params: { username: "nobody", password: "supersecret1" }

    assert_response :unauthorized
  end

  test "username match is case-insensitive" do
    post api_v1_owner_login_url, params: { username: "ADMIN", password: "supersecret1" }

    assert_response :success
  end

  test "does not set a device token" do
    post api_v1_owner_login_url, params: { username: "admin", password: "supersecret1" }

    body = JSON.parse(response.body)
    refute body.key?("token")
  end
end
