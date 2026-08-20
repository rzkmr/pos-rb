# Transactional changes flowing back to the device — kitchen marking a
# ticket ready, another terminal closing a session. See API-SPEC.md §8.
# Polled every 5-10s while the client is foregrounded; deliberately not
# pushed (no FCM — see ARCHITECTURE.md "Rejected").
#
# Shares the same api_sync_events ledger DeltaController reads, filtered
# to the "ticket" entity — reference-data changes and transactional
# changes are two logically separate streams (different cadence, different
# client-side handling) even though they're stored in one table today.
class Api::V1::UpdatesController < Api::V1::BaseController
  DEFAULT_LIMIT = 200
  MAX_LIMIT = 1000

  def show
    shop = Current.shop
    cursor = params.fetch(:cursor, 0).to_i
    limit = params[:limit].to_i.clamp(1, MAX_LIMIT)
    limit = DEFAULT_LIMIT if limit.zero?

    events = shop.api_sync_events.where(entity: "ticket").where("seq > ?", cursor).order(:seq).limit(limit).to_a

    render json: {
      cursor: events.last&.seq || cursor,
      changes: events.map { |event| { seq: event.seq, entity: event.entity, action: event.action, record: event.record } }
    }
  end
end
