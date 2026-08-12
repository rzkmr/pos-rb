require "test_helper"

class UnpairedDeviceTest < ActionDispatch::IntegrationTest
  test "any route other than pairing is blocked without a paired device" do
    get new_session_url
    assert_response :unauthorized
  end
end
