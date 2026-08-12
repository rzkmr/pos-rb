require "test_helper"

class Admin::DiningTablesControllerTest < ActionDispatch::IntegrationTest
  test "non-admin cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_dining_tables_url

    assert_response :forbidden
  end

  test "admin can create a table" do
    sign_in_as(users(:alpha_admin), pin: "1234")

    assert_difference "DiningTable.count", 1 do
      post admin_dining_tables_url, params: { dining_table: { label: "T9", seats: 4 } }
    end

    assert_redirected_to admin_dining_tables_path
  end

  test "admin can remove a table with no sessions" do
    sign_in_as(users(:alpha_admin), pin: "1234")
    table = shops(:alpha).dining_tables.create!(label: "T9", seats: 2, position: 9)

    assert_difference "DiningTable.count", -1 do
      delete admin_dining_table_url(table)
    end
  end

  test "admin cannot remove a table with sessions" do
    sign_in_as(users(:alpha_admin), pin: "1234")
    table = dining_tables(:alpha_t1)

    assert_no_difference "DiningTable.count" do
      delete admin_dining_table_url(table)
    end

    assert_redirected_to admin_dining_tables_path
  end
end
