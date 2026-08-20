# Emits an ApiSyncEvent row after every commit that changes an
# API-visible entity, so Api::V1::DeltaController can serve a cursor-based
# feed without re-deriving "what changed" from updated_at (API-SPEC.md §3
# — timestamp pagination drops same-millisecond writes and breaks under
# clock skew).
#
# ApiSyncEvent.record! row-locks the shop and increments its
# api_sync_cursor counter — an update, which itself runs through Shop's
# own after_commit chain. Shop does NOT include this concern (its
# api_sync_cursor bump is bookkeeping, not an API-visible entity change),
# so there is no re-entrant loop here; this concern only ever touches
# menu_item / dining_table / user, none of which write to `shops`.
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
      shop: shop,
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
