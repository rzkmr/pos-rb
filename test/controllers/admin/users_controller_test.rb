require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "non-admin cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_users_url

    assert_response :forbidden
  end

  test "admin can create a user with a PIN" do
    sign_in_as(users(:alpha_admin), pin: "1234")

    assert_difference "User.count", 1 do
      post admin_users_url, params: { user: { name: "New Cashier", role: "cashier", pin: "5555" } }
    end

    assert_redirected_to admin_users_path
  end

  test "update without a pin keeps the existing pin" do
    sign_in_as(users(:alpha_admin), pin: "1234")
    user = users(:alpha_waiter)
    original_digest = user.pin_digest

    patch admin_user_url(user), params: { user: { name: "Renamed Waiter", pin: "" } }

    assert_equal original_digest, user.reload.pin_digest
    assert_equal "Renamed Waiter", user.name
  end

  test "destroy deactivates instead of deleting" do
    sign_in_as(users(:alpha_admin), pin: "1234")
    user = users(:alpha_waiter)

    assert_no_difference "User.count" do
      delete admin_user_url(user)
    end

    assert_not user.reload.active?
  end
end
