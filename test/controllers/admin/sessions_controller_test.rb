require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new is reachable with no device paired and no shop-floor session" do
    get new_admin_session_url

    assert_response :success
  end

  test "create signs in with correct username and password" do
    post admin_session_url, params: { username: admin_users(:alpha_admin).username, password: "supersecret1" }

    assert_redirected_to admin_root_path
  end

  test "create rejects an incorrect password" do
    post admin_session_url, params: { username: admin_users(:alpha_admin).username, password: "wrongpassword" }

    assert_response :unprocessable_entity
  end

  test "username is case-insensitive" do
    post admin_session_url, params: { username: admin_users(:alpha_admin).username.upcase, password: "supersecret1" }

    assert_redirected_to admin_root_path
  end

  test "destroy signs out and redirects to admin login" do
    admin_sign_in_as(admin_users(:alpha_admin), password: "supersecret1")

    delete admin_session_url

    assert_redirected_to new_admin_session_path
  end
end
