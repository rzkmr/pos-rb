require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "any request redirects to setup when no shop exists" do
    Shop.stub(:exists?, false) do
      get root_url
    end

    assert_redirected_to new_setup_path
  end

  test "create bootstraps a second shop's admin and pairs this device" do
    Shop.stub(:exists?, false) do
      assert_difference [ "Shop.count", "User.count", "Device.unscoped.count" ], 1 do
        post setup_url, params: {
          name: "Bootstrap Shop",
          state_code: "36",
          address: "1 Test Road",
          admin_pin: "9999",
          admin_name: "Owner",
          admin_pin_login: "1234"
        }
      end
    end

    assert_redirected_to new_session_path
    assert_equal "admin", User.last.role
    assert cookies[:device_token].present?
  end

  test "create rejects a non-4-digit PIN" do
    Shop.stub(:exists?, false) do
      assert_no_difference "Shop.count" do
        post setup_url, params: {
          name: "Bootstrap Shop",
          state_code: "36",
          admin_pin: "99",
          admin_name: "Owner",
          admin_pin_login: "1234"
        }
      end
    end

    assert_response :unprocessable_entity
  end

  test "setup is unreachable once a shop already exists" do
    get new_setup_url

    assert_redirected_to root_path
  end
end
