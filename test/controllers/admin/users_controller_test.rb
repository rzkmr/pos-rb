require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  # admin_sign_in_as has no device cookie, so Authentication#set_current_shop
  # falls back to Shop.order(:id).first — with both fixture shops present
  # that's whichever way Rails' fixture-label hashing happens to order them
  # (not necessarily shops(:alpha)). Every test below expects admin_admin
  # to land on shops(:alpha), so remove shops(:beta) for the duration.
  setup do
    admin_users(:beta_admin).delete
    shops(:beta).delete
  end

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
    original_pin = user.pin

    patch admin_user_url(user), params: { user: { name: "Renamed Waiter", pin: "" } }

    assert_equal original_pin, user.reload.pin
    assert_equal "Renamed Waiter", user.name
  end

  test "edit shows the current PIN in the clear" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    user = users(:alpha_waiter)

    get edit_admin_user_url(user)

    assert_match user.pin, response.body
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

  test "destroy deactivates a user even if their pin is no longer valid" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    user = users(:alpha_waiter)
    user.update_column(:pin, nil)

    delete admin_user_url(user)

    assert_not user.reload.active?
  end
end
