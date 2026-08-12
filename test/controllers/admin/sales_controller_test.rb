require "test_helper"

class Admin::SalesControllerTest < ActionDispatch::IntegrationTest
  test "a signed-in shop-floor user cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_sales_url

    assert_redirected_to new_admin_session_path
  end

  test "admin can view today's sales" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    get admin_sales_url

    assert_response :success
  end

  test "invalid date redirects with an alert" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    get admin_sales_url, params: { date: "not-a-date" }

    assert_redirected_to admin_sales_path
  end
end
