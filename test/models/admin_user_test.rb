require "test_helper"

class AdminUserTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "authenticates with the correct password" do
    assert admin_users(:alpha_admin).authenticate("supersecret1")
  end

  test "rejects an incorrect password" do
    assert_not admin_users(:alpha_admin).authenticate("wrongpassword")
  end

  test "requires a username unique within the shop, case-insensitively" do
    Current.shop = shops(:alpha)
    duplicate = AdminUser.new(shop: shops(:alpha), username: admin_users(:alpha_admin).username.upcase, password: "supersecret1")

    assert_not duplicate.valid?
  end

  test "the same username is fine in a different shop" do
    Current.shop = nil
    admin = AdminUser.new(shop: shops(:beta), username: admin_users(:alpha_admin).username, password: "supersecret1")

    assert admin.valid?
  end

  test "requires a password of at least 8 characters on create" do
    Current.shop = shops(:alpha)
    admin = AdminUser.new(shop: shops(:alpha), username: "shortpw", password: "short")

    assert_not admin.valid?
  end
end
