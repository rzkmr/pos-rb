require "test_helper"

class Admin::MenuItemsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_menu_items_url

    assert_response :forbidden
  end

  test "admin can create a menu item" do
    sign_in_as(users(:alpha_admin), pin: "1234")

    assert_difference "MenuItem.count", 1 do
      post admin_menu_items_url, params: { menu_item: { name: "Idli", category: "main", price_paise: 5000, hsn_sac: "996331" } }
    end

    assert_redirected_to admin_menu_items_path
  end

  test "admin destroy deactivates instead of deleting" do
    sign_in_as(users(:alpha_admin), pin: "1234")
    menu_item = menu_items(:alpha_dosa)

    assert_no_difference "MenuItem.count" do
      delete admin_menu_item_url(menu_item)
    end

    assert_not menu_item.reload.active?
  end
end
