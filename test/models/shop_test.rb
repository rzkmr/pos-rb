require "test_helper"

class ShopTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "authenticates the device pairing pin" do
    assert shops(:alpha).authenticate_pairing_pin("9999")
    assert_not shops(:alpha).authenticate_pairing_pin("0000")
  end

  test "next_invoice_sequence! increments gaplessly within a financial year" do
    shop = shops(:alpha)

    first = shop.next_invoice_sequence!("2082/83")
    second = shop.next_invoice_sequence!("2082/83")

    assert_equal 1, first
    assert_equal 2, second
  end

  test "next_invoice_sequence! resets the counter on financial year rollover" do
    shop = shops(:alpha)
    shop.next_invoice_sequence!("2082/83")

    reset = shop.next_invoice_sequence!("2083/84")

    assert_equal 1, reset
  end

  test "refuses to create a second shop when one already exists" do
    shop = Shop.new(name: "Second Shop", invoice_prefix: "INV", invoice_fy: "2082/83")

    assert_not shop.save
    assert_includes shop.errors[:base], "a shop already exists — this deployment is single-shop only"
  end
end
