require "test_helper"

class Api::V1::Owner::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "returns owner identity and a session token for valid credentials" do
    assert_difference "OwnerSession.count", 1 do
      post api_v1_owner_login_url, params: { username: "admin", password: "supersecret1" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal admin_users(:alpha_admin).id, body["owner"]["id"]
    assert_equal "admin", body["owner"]["username"]
    assert_equal shops(:alpha).id, body["shop_id"]
    assert body["owner_session_token"].present?
  end

  test "issued token authenticates a later logout call" do
    post api_v1_owner_login_url, params: { username: "admin", password: "supersecret1" }
    token = JSON.parse(response.body)["owner_session_token"]

    assert_difference "OwnerSession.count", -1 do
      delete api_v1_owner_logout_url, headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :no_content
  end

  test "logout 401s without a valid token" do
    delete api_v1_owner_logout_url, headers: { "Authorization" => "Bearer bogus" }

    assert_response :unauthorized
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

  test "no_shop_configured when there is no shop" do
    Shop.stub :order, ->(*) { Shop.none } do
      post api_v1_owner_login_url, params: { username: "admin", password: "supersecret1" }
    end

    assert_response :unprocessable_entity
    assert_equal "no_shop_configured", JSON.parse(response.body)["error"]
  end
end
