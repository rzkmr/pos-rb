require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "no device cookie renders the not-paired screen instead of the app" do
    get root_url

    assert_response :unauthorized
    assert_select "body", /not.*paired/i
  end

  test "a garbage device cookie is treated the same as no device" do
    cookies[:device_token] = "not-a-real-token"

    get root_url

    assert_response :unauthorized
  end

  test "a valid device token from a different shop does not authenticate here" do
    other_shop = shops(:beta)
    _device, token = Device.pair!(shop: other_shop, label: "Other shop tablet")
    cookies[:device_token] = token

    get root_url

    assert_response :unauthorized
  end

  test "a revoked device's token stops working on the very next request" do
    device, token = Device.pair!(shop: shops(:alpha), label: "Soon revoked")
    cookies[:device_token] = token
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    delete device_url(device)

    get root_url

    assert_response :unauthorized
  end

  test "a paired device without a signed-in user is redirected to pick a user, not blocked" do
    _device, token = Device.pair!(shop: shops(:alpha), label: "Test")
    cookies[:device_token] = token

    get root_url

    assert_redirected_to new_session_url
  end

  test "a paired device with a signed-in user reaches the app" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get root_url

    assert_response :success
  end

  test "the user session does not carry over to a different device's cookie" do
    sign_in_as(users(:alpha_waiter), pin: "2222")
    _second_device, second_token = Device.pair!(shop: shops(:alpha), label: "Second tablet")

    cookies[:device_token] = second_token

    get root_url

    # require_device runs before require_user, so an unrecognized device
    # cookie is rejected outright rather than falling through to sign-in.
    assert_response :unauthorized
  end

  test "deactivating the signed-in user locks them out on their very next request" do
    sign_in_as(users(:alpha_waiter), pin: "2222")
    users(:alpha_waiter).update_column(:active, false)

    get root_url

    assert_redirected_to new_session_url
  end

  test "touches the device's last_seen_at on each authenticated request" do
    device, token = Device.pair!(shop: shops(:alpha), label: "Test")
    cookies[:device_token] = token
    assert_nil device.last_seen_at

    get pair_devices_url # any route that runs set_current_device
    travel 1.minute
    get new_session_url

    assert device.reload.last_seen_at.present?
  end

  test "admin login does not require or consult device pairing" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    get admin_root_url

    assert_response :success
  end
end
