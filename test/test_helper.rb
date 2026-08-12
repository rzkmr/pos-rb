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
    device, token = Device.pair!(shop: shop, label: "Test Device", kind: "waiter")
    cookies[:device_token] = token
    post session_url, params: { user_id: user.id, pin: pin }
    device
  end
end

ActionDispatch::IntegrationTest.include SignsInAsUser
