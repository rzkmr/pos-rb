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
end
