# Per-shop counter for ApiSyncEvent#seq, kept off the shops row so
# incrementing it is never itself a write to `shops` — see
# db/migrate/*_create_shop_sync_cursors for why that recursion mattered.
class ShopSyncCursor < ApplicationRecord
  belongs_to :shop

  def self.value_for(shop)
    find_by(shop: shop)&.value || 0
  end

  # Row-locks this shop's cursor row and hands out the next seq. Mirrors
  # the row-lock-and-increment pattern Shop#next_invoice_sequence! uses
  # for invoice numbers — same reasoning: two concurrent writers must
  # never receive the same value.
  def self.increment_for!(shop)
    cursor = lock.find_or_create_by!(shop: shop)
    cursor.increment!(:value)
    cursor.value
  end
end
