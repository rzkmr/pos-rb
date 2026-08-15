require "test_helper"

class HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "show returns ok" do
    get heartbeat_url

    assert_response :success
  end

  test "show returns ok with no device paired or user signed in" do
    delete session_url

    get heartbeat_url

    assert_response :success
  end
end
