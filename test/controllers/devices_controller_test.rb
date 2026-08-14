require "test_helper"

class DevicesControllerTest < ActionDispatch::IntegrationTest
  test "pair page is reachable without a paired device" do
    get pair_devices_url
    assert_response :success
  end

  test "create pairs a device with the correct admin pin" do
    assert_difference "Device.unscoped.count", 1 do
      post devices_url, params: { admin_pin: "9999" }
    end

    assert_redirected_to new_session_url
    assert cookies[:device_token].present?
  end

  test "create redirects an admin back to the devices list, not staff PIN login" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    post devices_url, params: { admin_pin: "9999" }

    assert_redirected_to devices_path
  end

  test "create rejects an incorrect admin pin" do
    assert_no_difference "Device.unscoped.count" do
      post devices_url, params: { admin_pin: "0000" }
    end

    assert_response :unprocessable_entity
  end

  test "create records a pairing_attempt for both success and failure" do
    assert_difference "PairingAttempt.count", 1 do
      post devices_url, params: { admin_pin: "9999" }
    end
    assert shops(:alpha).pairing_attempts.last.success

    assert_difference "PairingAttempt.count", 1 do
      post devices_url, params: { admin_pin: "0000" }
    end
    assert_not shops(:alpha).pairing_attempts.last.success
  end

  test "create is locked out shop-wide after repeated failures, even with the correct PIN" do
    PairingAttempt::LOCKOUT_THRESHOLD.times do
      shops(:alpha).pairing_attempts.create!(success: false, ip_address: "10.0.0.#{rand(1..254)}")
    end

    assert_no_difference "Device.unscoped.count" do
      post devices_url, params: { admin_pin: "9999" }
    end

    assert_response :too_many_requests
  end

  test "index requires admin web login, not a paired device or PIN" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get devices_url

    assert_redirected_to new_admin_session_path
  end

  test "destroy requires admin web login and writes an audit_event" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    device, = Device.pair!(shop: shops(:alpha), label: "Old tablet")

    assert_difference "AuditEvent.count", 1 do
      delete device_url(device)
    end

    assert_not Device.unscoped.exists?(device.id)
  end
end
