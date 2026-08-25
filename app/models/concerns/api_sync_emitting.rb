# Emits an ApiSyncEvent row after every commit that changes an
# API-visible entity, so Api::V1::DeltaController can serve a cursor-based
# feed without re-deriving "what changed" from updated_at (API-SPEC.md §3
# — timestamp pagination drops same-millisecond writes and breaks under
# clock skew).
#
# ApiSyncEvent.record! hands out the next seq via ShopSyncCursor, a
# separate row-locked table — not a write to `shops` itself — which is
# what lets Shop include this concern safely (shop-setting changes like
# service_charge_enabled flipping need to reach clients via /delta too).
# See db/migrate/*_create_shop_sync_cursors for why that matters.
module ApiSyncEmitting
  extend ActiveSupport::Concern

  included do
    after_commit :emit_api_sync_event
  end

  private

  def emit_api_sync_event
    return if destroyed? && previously_new_record? # created-then-destroyed in one request: nothing to tell a client

    action = destroyed? ? "delete" : "upsert"
    ApiSyncEvent.record!(
      shop: is_a?(Shop) ? self : shop,
      entity: model_name.element,
      action: action,
      record_id: id,
      record: action == "delete" ? { "id" => id } : api_sync_record
    )
  end

  # Override in the including model to control exactly what ships in the
  # delta payload — defaults to nothing beyond the tombstone id, which
  # would silently under-inform clients, so every includer must define it.
  def api_sync_record
    raise NotImplementedError, "#{self.class} must define #api_sync_record for ApiSyncEmitting"
  end
end
