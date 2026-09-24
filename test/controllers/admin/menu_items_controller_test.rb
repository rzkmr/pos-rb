require "test_helper"

class Admin::MenuItemsControllerTest < ActionDispatch::IntegrationTest
  # admin_sign_in_as has no device cookie, so Authentication#set_current_shop
  # falls back to Shop.order(:id).first — with both fixture shops present
  # that's whichever way Rails' fixture-label hashing happens to order them
  # (not necessarily shops(:alpha)). Every test below expects admin_admin
  # to land on shops(:alpha), so remove shops(:beta) for the duration.
  setup do
    admin_users(:beta_admin).delete
    shops(:beta).delete
  end

  test "unauthenticated admin request redirects to admin login" do
    get admin_menu_items_url

    assert_redirected_to new_admin_session_path
  end

  test "a signed-in shop-floor user cannot access, even on a paired device" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_menu_items_url

    assert_redirected_to new_admin_session_path
  end

  test "admin can create a menu item, entering the price in rupees" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    assert_difference "MenuItem.count", 1 do
      post admin_menu_items_url, params: { menu_item: { name: "Idli", category: "main", gross_price_rupees: "50.50" } }
    end

    assert_redirected_to admin_menu_items_path
    assert_equal 5050, MenuItem.last.gross_price_paisa
  end

  test "admin can update a menu item's price, entering rupees" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    menu_item = menu_items(:alpha_dosa)

    patch admin_menu_item_url(menu_item), params: { menu_item: { gross_price_rupees: "180" } }

    assert_redirected_to admin_menu_items_path
    assert_equal 18000, menu_item.reload.gross_price_paisa
  end

  test "edit prefills the price field in rupees, not paisa" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    menu_item = menu_items(:alpha_dosa) # gross_price_paisa: 12000

    get edit_admin_menu_item_url(menu_item)

    assert_select "input#menu_item_gross_price_rupees[value=?]", "120.0"
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
