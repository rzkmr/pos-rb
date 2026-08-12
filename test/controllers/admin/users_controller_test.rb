require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "a signed-in shop-floor user cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_users_url

    assert_redirected_to new_admin_session_path
  end

  test "admin can create a user with a PIN" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    assert_difference "User.count", 1 do
      post admin_users_url, params: { user: { name: "New Cashier", role: "cashier", pin: "5555" } }
    end

    assert_redirected_to admin_users_path
  end

  test "the admin role can no longer be assigned to a User" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    assert_no_difference "User.count" do
      post admin_users_url, params: { user: { name: "Sneaky", role: "admin", pin: "5555" } }
    end

    assert_response :unprocessable_entity
  end

  test "update without a pin keeps the existing pin" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    user = users(:alpha_waiter)
    original_digest = user.pin_digest

    patch admin_user_url(user), params: { user: { name: "Renamed Waiter", pin: "" } }

    assert_equal original_digest, user.reload.pin_digest
    assert_equal "Renamed Waiter", user.name
  end

  test "destroy deactivates instead of deleting, and writes an audit_event" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    user = users(:alpha_waiter)

    assert_no_difference "User.count" do
      assert_difference "AuditEvent.count", 1 do
        delete admin_user_url(user)
      end
    end

    assert_not user.reload.active?
  end
end
