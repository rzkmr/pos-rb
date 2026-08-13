require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "a signed-in shop-floor user cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get edit_admin_settings_url

    assert_redirected_to new_admin_session_path
  end

  test "admin can set the printer host and port, and it writes an audit_event" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    assert_difference "AuditEvent.count", 1 do
      patch admin_settings_url, params: { shop: { printer_host: "192.168.1.20", printer_port: 9100 } }
    end

    assert_redirected_to edit_admin_settings_path
    assert_equal "192.168.1.20", shops(:alpha).reload.printer_host
  end

  test "edit shows the current pairing PIN in the clear" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    get edit_admin_settings_url

    assert_match shops(:alpha).pairing_pin, response.body
  end

  test "admin can change the pairing PIN, and the old one stops working" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    patch admin_settings_url, params: { shop: { name: shops(:alpha).name }, admin_pin: "5678" }

    assert_equal "5678", shops(:alpha).reload.pairing_pin
    assert_not shops(:alpha).authenticate_pairing_pin("9999")
  end

  test "leaving the pairing PIN blank keeps the current one" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    original = shops(:alpha).pairing_pin

    patch admin_settings_url, params: { shop: { name: shops(:alpha).name }, admin_pin: "" }

    assert_equal original, shops(:alpha).reload.pairing_pin
  end
end
