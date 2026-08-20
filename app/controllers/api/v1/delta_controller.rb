# Incremental reference-data changes (menu, tables, users, shop settings)
# since the client's last-applied cursor. See API-SPEC.md §3 — cursor-
# based, never updated_after; deletes are tombstones in the same stream.
class Api::V1::DeltaController < Api::V1::BaseController
  DEFAULT_LIMIT = 200
  MAX_LIMIT = 1000

  # api_sync_events rows are only ever pruned by a future retention job
  # that does not exist yet, so cursor_too_old cannot actually happen
  # today — the branch exists so DeltaController never silently serves a
  # gap if pruning is added later without this file being revisited.
  def show
    shop = Current.shop
    cursor = params.fetch(:cursor, 0).to_i
    limit = params[:limit].to_i.clamp(1, MAX_LIMIT)
    limit = DEFAULT_LIMIT if limit.zero?

    oldest_available = shop.api_sync_events.minimum(:seq)
    if oldest_available && cursor.positive? && cursor < oldest_available - 1
      return render json: { error: "cursor_too_old" }, status: :conflict
    end

    events = shop.api_sync_events.where("seq > ?", cursor).order(:seq).limit(limit + 1).to_a
    has_more = events.size > limit
    events = events.first(limit)

    render json: {
      cursor: events.last&.seq || cursor,
      has_more: has_more,
      server_time: Time.current.iso8601,
      changes: events.map { |event| change_payload(event) }
    }
  end

  private

  def change_payload(event)
    { seq: event.seq, entity: event.entity, action: event.action, record: event.record }
  end
end
