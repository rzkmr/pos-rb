# A parked takeaway cart (design_system §8 "Hold"). Items are a plain snapshot
# — name, unit price, quantity — captured at hold time, the same reasoning as
# ticket_item snapshots (CLAUDE.md invariant #6): a menu edit between hold and
# restore must never change what the cart charges.
class HeldCart < ApplicationRecord
  include ShopScoped

  belongs_to :dining_table
  belongs_to :held_by, class_name: "User"

  validates :items, presence: true
  validates :held_at, presence: true

  def total_paisa
    items.sum { |item| item["quantity"].to_i * item["unit_price_paisa"].to_i }
  end

  def item_count
    items.sum { |item| item["quantity"].to_i }
  end
end
