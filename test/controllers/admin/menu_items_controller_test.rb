require "test_helper"

class Admin::MenuItemsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated admin request redirects to admin login" do
    get admin_menu_items_url

    assert_redirected_to new_admin_session_path
  end

  test "a signed-in shop-floor user cannot access, even on a paired device" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_menu_items_url

    assert_redirected_to new_admin_session_path
  end

  test "admin can create a menu item" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    assert_difference "MenuItem.count", 1 do
      post admin_menu_items_url, params: { menu_item: { name: "Idli", category: "main", gross_price_paisa: 5000 } }
    end

    assert_redirected_to admin_menu_items_path
  end

  test "admin destroy deactivates instead of deleting, and writes an audit_event" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    menu_item = menu_items(:alpha_dosa)

    assert_no_difference "MenuItem.count" do
      assert_difference "AuditEvent.count", 1 do
        delete admin_menu_item_url(menu_item)
      end
    end

    assert_not menu_item.reload.active?
    assert_equal admin_users(:alpha_admin), AuditEvent.last.admin_user
  end
end
