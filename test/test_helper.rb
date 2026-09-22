ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module SignsAsDevice
  # Integration tests' `cookies` is a Rack::Test::CookieJar (see
  # ActionDispatch::Integration::Session#cookies) — it has no `signed`
  # accessor at all, unlike a real controller's ActionDispatch::Cookies
  # jar. Authentication#set_current_device reads cookies.signed, so a
  # plain `cookies[:device_token] = token` is never authenticated — it
  # just always 401s, silently, because signed returns nil for a value
  # it can't verify. This builds a real ActionDispatch cookie jar against
  # nothing but this process's own secret_key_base (the same key the app
  # itself signs with) purely to get the wire-format signed string, then
  # sets that as a plain string cookie — which is exactly what a real
  # signed cookie looks like on the wire to whoever reads it.
  def signed_device_cookie(token)
    jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    jar.signed[:device_token] = token
    jar[:device_token]
  end
end

module SignsInAsUser
  include SignsAsDevice

  def sign_in_as(user, pin:, shop: user.shop)
    device, token = Device.pair!(shop: shop, label: "Test Device")
    cookies[:device_token] = signed_device_cookie(token)
    post session_url, params: { user_id: user.id, pin: pin }
    device
  end

  # Admin login is username + password, independent of device pairing.
  def admin_sign_in_as(admin_user, password:)
    post admin_session_url, params: { username: admin_user.username, password: password }
  end
end

ActionDispatch::IntegrationTest.include SignsAsDevice
ActionDispatch::IntegrationTest.include SignsInAsUser

module ApiAuthentication
  # Pairs a fresh device and returns the Bearer header hash for
  # Api::V1::BaseController — the token-authenticated API has no cookie
  # session (see Api::V1::BaseController), so every request needs this
  # explicitly rather than a one-time sign_in.
  def api_headers_for(shop:, label: "API Test Device")
    _device, token = Device.pair!(shop: shop, label: label)
    { "Authorization" => "Bearer #{token}" }
  end
end

ActionDispatch::IntegrationTest.include ApiAuthentication
