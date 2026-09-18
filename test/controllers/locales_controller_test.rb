require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "before sign-in, redirects back to the referring page instead of root" do
    patch locale_url(locale: "ne"), headers: { "HTTP_REFERER" => new_admin_session_url }

    assert_redirected_to new_admin_session_url
  end

  test "before sign-in, stores the choice in session for that request" do
    patch locale_url(locale: "ne"), headers: { "HTTP_REFERER" => new_admin_session_url }

    assert_equal "ne", session[:locale]
  end

  test "signed-in admin's locale choice is persisted on the admin" do
    admin = admin_users(:alpha_admin)
    admin_sign_in_as(admin, password: "supersecret1")

    patch locale_url(locale: "ne"), headers: { "HTTP_REFERER" => admin_root_url }

    assert_redirected_to admin_root_url
    assert_equal "ne", admin.reload.locale
  end
end
