require "test_helper"

class ShopScopedTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "default scope hides other shops' records when Current.shop is set" do
    Current.shop = shops(:alpha)

    assert_includes User.all, users(:alpha_admin)
    assert_not_includes User.all, users(:beta_admin)
  end

  test "without Current.shop all shops are visible" do
    Current.shop = nil

    assert_includes User.all, users(:beta_admin)
  end

  test "new records default to Current.shop" do
    Current.shop = shops(:alpha)

    table = DiningTable.new(label: "T9", seats: 4)
    table.valid?

    assert_equal shops(:alpha), table.shop
  end
end
