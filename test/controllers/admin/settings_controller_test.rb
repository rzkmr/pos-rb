require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get edit_admin_settings_url

    assert_response :forbidden
  end

  test "admin can set the printer host and port" do
    sign_in_as(users(:alpha_admin), pin: "1234")

    patch admin_settings_url, params: { shop: { printer_host: "192.168.1.20", printer_port: 9100 } }

    assert_redirected_to edit_admin_settings_path
    assert_equal "192.168.1.20", shops(:alpha).reload.printer_host
  end
end
