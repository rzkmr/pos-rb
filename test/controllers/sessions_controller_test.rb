require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shop = shops(:alpha)
    @device, @token = Device.pair!(shop: @shop, label: "Test", kind: "waiter")
    cookies[:device_token] = @token
  end

  test "new is reachable when a device is paired" do
    get new_session_url
    assert_response :success
  end

  test "create signs in with correct pin and redirects" do
    post session_url, params: { user_id: users(:alpha_waiter).id, pin: "2222" }
    assert_redirected_to root_url
  end

  test "create rejects an incorrect pin" do
    post session_url, params: { user_id: users(:alpha_waiter).id, pin: "0000" }
    assert_response :unprocessable_entity
  end

  test "destroy signs out and redirects to login" do
    post session_url, params: { user_id: users(:alpha_waiter).id, pin: "2222" }
    delete session_url
    assert_redirected_to new_session_url
  end
end
