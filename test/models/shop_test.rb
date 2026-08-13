require "test_helper"

class ShopTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "authenticates the device pairing pin" do
    assert shops(:alpha).authenticate_pairing_pin("9999")
    assert_not shops(:alpha).authenticate_pairing_pin("0000")
  end

  test "next_invoice_sequence! increments gaplessly within a financial year" do
    shop = shops(:alpha)

    first = shop.next_invoice_sequence!("2025-26")
    second = shop.next_invoice_sequence!("2025-26")

    assert_equal 1, first
    assert_equal 2, second
  end

  test "next_invoice_sequence! resets the counter on financial year rollover" do
    shop = shops(:alpha)
    shop.next_invoice_sequence!("2025-26")

    reset = shop.next_invoice_sequence!("2026-27")

    assert_equal 1, reset
  end
end
