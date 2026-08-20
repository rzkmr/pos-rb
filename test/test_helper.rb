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

module SignsInAsUser
  def sign_in_as(user, pin:, shop: user.shop)
    device, token = Device.pair!(shop: shop, label: "Test Device")
    cookies[:device_token] = token
    post session_url, params: { user_id: user.id, pin: pin }
    device
  end

  # Admin login is username + password, independent of device pairing.
  def admin_sign_in_as(admin_user, password:)
    post admin_session_url, params: { username: admin_user.username, password: password }
  end
end

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
