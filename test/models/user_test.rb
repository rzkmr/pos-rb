require "test_helper"

class UserTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "authenticates with correct pin" do
    assert users(:alpha_admin).authenticate_pin("1234")
  end

  test "rejects incorrect pin" do
    assert_not users(:alpha_admin).authenticate_pin("0000")
  end

  test "requires a 4-digit pin on create" do
    Current.shop = shops(:alpha)
    user = User.new(name: "New", role: "waiter", pin: "12")

    assert_not user.valid?
    assert_includes user.errors[:pin], "must be 4 digits"
  end

  test "requires a valid role" do
    Current.shop = shops(:alpha)
    user = User.new(name: "New", role: "manager", pin: "1234")

    assert_not user.valid?
  end
end
