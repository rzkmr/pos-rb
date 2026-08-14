# Every device-pairing attempt against the shop's pairing PIN, success or
# failure. Backs a shop-wide lockout (recent failures regardless of which
# IP made them) and gives admin visibility into brute-force attempts,
# which previously left no trace at all. See DevicesController#create.
class PairingAttempt < ApplicationRecord
  include ShopScoped

  LOCKOUT_THRESHOLD = 8
  LOCKOUT_WINDOW = 15.minutes

  def self.locked_out?(shop:)
    shop.pairing_attempts.where(success: false).where(created_at: LOCKOUT_WINDOW.ago..).count >= LOCKOUT_THRESHOLD
  end
end
