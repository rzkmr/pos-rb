require "test_helper"

class Admin::SalesControllerTest < ActionDispatch::IntegrationTest
  test "non-admin cannot access" do
    sign_in_as(users(:alpha_waiter), pin: "2222")

    get admin_sales_url

    assert_response :forbidden
  end

  test "admin can view today's sales" do
    sign_in_as(users(:alpha_admin), pin: "1234")

    get admin_sales_url

    assert_response :success
  end

  test "invalid date redirects with an alert" do
    sign_in_as(users(:alpha_admin), pin: "1234")

    get admin_sales_url, params: { date: "not-a-date" }

    assert_redirected_to admin_sales_path
  end
end
