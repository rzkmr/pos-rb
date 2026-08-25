# Append-only delta log consumed by Api::V1::DeltaController. See
# db/migrate/*_create_api_sync_events and API-SPEC.md §3 — cursor-based,
# never updated_after timestamps, and deletes must appear as tombstones or
# a removed menu item lives on the client forever.
class ApiSyncEvent < ApplicationRecord
  include ShopScoped

  ENTITIES = %w[shop menu_item dining_table user ticket].freeze
  # "shop" was already listed above in anticipation of this — Shop did not
  # actually include ApiSyncEmitting until the cursor moved off its own
  # row (see db/migrate/*_create_shop_sync_cursors and Shop#api_sync_record).
  ACTIONS = %w[upsert delete status].freeze

  validates :entity, inclusion: { in: ENTITIES }
  validates :action, inclusion: { in: ACTIONS }
  validates :record_id, presence: true
  validates :seq, presence: true

  def readonly?
    persisted?
  end

  # Hands out a gapless seq via ShopSyncCursor's row lock — same reasoning
  # as Shop#next_invoice_sequence! for invoice numbers: two concurrent
  # writes must never receive the same cursor value. The counter lives off
  # the shops row precisely so this can run without Shop itself needing to
  # emit an ApiSyncEvent for its own bookkeeping write (see
  # db/migrate/*_create_shop_sync_cursors).
  def self.record!(shop:, entity:, action:, record_id:, record: {})
    seq = ShopSyncCursor.increment_for!(shop)
    create!(shop: shop, seq: seq, entity: entity, action: action, record_id: record_id, record: record)
  end
end
