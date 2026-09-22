require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "no device cookie renders the not-paired screen instead of the app" do
    get dining_tables_url

    assert_response :unauthorized
    assert_select "body", /not.*paired/i
  end

  test "a garbage device cookie is treated the same as no device" do
    cookies[:device_token] = "not-a-real-token"

    get dining_tables_url

    assert_response :unauthorized
  end

  # Current.shop is derived from the device's own token (Authentication
  # #authenticated_device), not a fixed default — a device from a
  # different shop authenticates fine, but scoped to its OWN shop, never
  # the wrong one. This is what actually matters for multi-tenancy
  # (ARCHITECTURE.md §14); "reject any other shop's device outright" was
  # never a real property, it only looked like one while Current.shop was
  # hardcoded to Shop.order(:id).first and a second shop's device
  # happened not to be found in the wrong shop's device list.
  test "a valid device token from a different shop resolves that shop, not the wrong one" do
    other_shop = shops(:beta)
    device, token = Device.pair!(shop: other_shop, label: "Other shop tablet")
    cookies[:device_token] = signed_device_cookie(token)
    assert_nil device.last_seen_at

    get dining_tables_url

    # Correctly scoped: reaches the app (redirected to pick a user, same
    # as any freshly-paired device with no signed-in session yet), on
    # the device's own shop — never a cross-tenant 401 or, worse, a
    # silent mis-scope to the wrong shop's data. last_seen_at is only
    # ever touched by set_current_device authenticating THIS device, so
    # its presence proves the token resolved to its own shop correctly,
    # not merely that some request succeeded.
    assert_redirected_to new_session_url
    assert device.reload.last_seen_at.present?
  end

  test "a revoked device's token stops working on the very next request" do
    device, token = Device.pair!(shop: shops(:alpha), label: "Soon revoked")
    cookies[:device_token] = signed_device_cookie(token)
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    delete device_url(device)

    get dining_tables_url

    assert_response :unauthorized
  end

  test "a paired device without a signed-in user is redirected to pick a user, not blocked" do
    _device, token = Device.pair!(shop: shops(:alpha), label: "Test")
    cookies[:device_token] = signed_device_cookie(token)

    get dining_tables_url

    assert_redirected_to new_session_url
  end

  test "a paired device with a signed-in user reaches the app" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get dining_tables_url

    assert_response :success
  end

  test "the user session does not carry over to a different device's cookie" do
    sign_in_as(users(:alpha_waiter), pin: "2222")
    _second_device, second_token = Device.pair!(shop: shops(:alpha), label: "Second tablet")

    cookies[:device_token] = signed_device_cookie(second_token)

    get dining_tables_url

    # The second device is itself perfectly valid (same shop, correctly
    # paired) — require_device passes. What must NOT happen is the
    # existing user session silently carrying over to it: session[:user_id]
    # is bound to session[:device_id] (Authentication#set_current_user),
    # so a mismatched device falls through to require_user, same as no
    # session at all — re-enter the PIN on this device.
    assert_redirected_to new_session_url
  end

  test "deactivating the signed-in user locks them out on their very next request" do
    sign_in_as(users(:alpha_waiter), pin: "2222")
    users(:alpha_waiter).update_column(:active, false)

    get dining_tables_url

    assert_redirected_to new_session_url
  end

  test "touches the device's last_seen_at on each authenticated request" do
    device, token = Device.pair!(shop: shops(:alpha), label: "Test")
    cookies[:device_token] = signed_device_cookie(token)
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
