# Append-only delta log consumed by Api::V1::DeltaController. See
# db/migrate/*_create_api_sync_events and API-SPEC.md §3 — cursor-based,
# never updated_after timestamps, and deletes must appear as tombstones or
# a removed menu item lives on the client forever.
class ApiSyncEvent < ApplicationRecord
  include ShopScoped

  ENTITIES = %w[shop menu_item dining_table user ticket].freeze
  ACTIONS = %w[upsert delete status].freeze

  validates :entity, inclusion: { in: ENTITIES }
  validates :action, inclusion: { in: ACTIONS }
  validates :record_id, presence: true
  validates :seq, presence: true

  def readonly?
    persisted?
  end

  # Row-locks the shop to hand out a gapless seq, exactly like
  # Shop#next_invoice_sequence! does for invoice numbers — same reasoning:
  # two concurrent writes must never receive the same cursor value.
  def self.record!(shop:, entity:, action:, record_id:, record: {})
    shop.with_lock do
      seq = shop.increment!(:api_sync_cursor).api_sync_cursor
      create!(shop: shop, seq: seq, entity: entity, action: action, record_id: record_id, record: record)
    end
  end
end
