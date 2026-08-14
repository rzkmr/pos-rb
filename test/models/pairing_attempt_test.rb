require "test_helper"

class PairingAttemptTest < ActiveSupport::TestCase
  test "not locked out below the failure threshold" do
    (PairingAttempt::LOCKOUT_THRESHOLD - 1).times do
      shops(:alpha).pairing_attempts.create!(success: false, ip_address: "10.0.0.1")
    end

    assert_not PairingAttempt.locked_out?(shop: shops(:alpha))
  end

  test "locked out once the failure threshold is reached, regardless of IP" do
    PairingAttempt::LOCKOUT_THRESHOLD.times do |i|
      shops(:alpha).pairing_attempts.create!(success: false, ip_address: "10.0.0.#{i}")
    end

    assert PairingAttempt.locked_out?(shop: shops(:alpha))
  end

  test "successful attempts do not count toward lockout" do
    PairingAttempt::LOCKOUT_THRESHOLD.times do
      shops(:alpha).pairing_attempts.create!(success: true, ip_address: "10.0.0.1")
    end

    assert_not PairingAttempt.locked_out?(shop: shops(:alpha))
  end

  test "failures outside the lockout window do not count" do
    travel_to PairingAttempt::LOCKOUT_WINDOW.ago - 1.minute do
      PairingAttempt::LOCKOUT_THRESHOLD.times do |i|
        shops(:alpha).pairing_attempts.create!(success: false, ip_address: "10.0.0.#{i}")
      end
    end

    assert_not PairingAttempt.locked_out?(shop: shops(:alpha))
  end

  test "lockout is scoped per shop" do
    PairingAttempt::LOCKOUT_THRESHOLD.times do |i|
      shops(:alpha).pairing_attempts.create!(success: false, ip_address: "10.0.0.#{i}")
    end

    assert_not PairingAttempt.locked_out?(shop: shops(:beta))
  end
end
