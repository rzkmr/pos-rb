require "test_helper"

class Admin::DiningTablesControllerTest < ActionDispatch::IntegrationTest
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

    get admin_dining_tables_url

    assert_redirected_to new_admin_session_path
  end

  test "admin can create a table" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    assert_difference "DiningTable.count", 1 do
      post admin_dining_tables_url, params: { dining_table: { label: "T9", seats: 4 } }
    end

    assert_redirected_to admin_dining_tables_path
  end

  test "admin can remove a table with no sessions, and it writes an audit_event" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    table = shops(:alpha).dining_tables.create!(label: "T9", seats: 2, position: 9)

    assert_difference "DiningTable.count", -1 do
      assert_difference "AuditEvent.count", 1 do
        delete admin_dining_table_url(table)
      end
    end
  end

  test "admin cannot remove a table with sessions" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")
    table = dining_tables(:alpha_t1)

    assert_no_difference "DiningTable.count" do
      delete admin_dining_table_url(table)
    end

    assert_redirected_to admin_dining_tables_path
  end
end
