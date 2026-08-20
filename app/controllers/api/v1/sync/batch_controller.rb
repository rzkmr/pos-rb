# The outbox drain — API-SPEC.md §4. Thin translation layer over
# Sync::Replay (the same idempotent dispatcher the in-browser PWA's
# Sync::ActionsController already uses): maps the API's dotted `type`
# vocabulary onto Sync::Replay's internal handler `kind`s, resolves
# acting_user_id per operation (there is no server-side user session over
# the API — see Api::V1::BaseController), and translates Sync::Replay's
# applied/duplicate/rejected statuses onto the spec's
# accepted/duplicate/rejected/deferred vocabulary.
#
# Always 200, even with per-operation failures inside — see API-SPEC.md
# §4: a malformed row must reject just that row, never the whole batch,
# and must never come back as 500.
class Api::V1::Sync::BatchController < Api::V1::BaseController
  TYPE_TO_KIND = {
    "table_session.open" => "open_table_session",
    "ticket.create" => "submit_ticket",
    "ticket.status" => "update_ticket_status",
    "ticket_item.void" => "void_ticket_item",
    "table_session.discount" => "apply_discount",
    "invoice.issue" => "issue_invoice",
    "payment.record" => "record_payment",
    "table_session.close" => "close_table_session"
  }.freeze

  def create
    device_time = parse_device_time
    clock_skew_seconds = device_time ? (Time.current - device_time).round : nil

    results = operations_params.map { |operation| replay_one(operation) }

    render json: {
      server_time: Time.current.iso8601,
      clock_skew_seconds: clock_skew_seconds,
      cursor: Current.shop.api_sync_cursor,
      results: results
    }
  end

  private

  def replay_one(operation)
    op_id = operation.fetch(:op_id)
    type = operation.fetch(:type)
    kind = TYPE_TO_KIND[type]
    unless kind
      return { op_id: op_id, status: "rejected", retryable: false, code: "validation_failed", message: "unknown type: #{type}" }
    end

    payload = operation.fetch(:payload, {}).to_h
    acting_user = resolve_acting_user(operation, payload)

    outcome = Sync::Replay.call(
      shop: Current.shop, device: Current.device, user: acting_user,
      client_action_id: op_id, kind: kind, payload: payload
    )

    translate(op_id, outcome)
  rescue Sync::ActingUser::Unresolved => e
    { op_id: op_id, status: "rejected", retryable: false, code: "validation_failed", message: e.message }
  rescue => e
    Rails.error.report(e, handled: true, context: { op_id: op_id, type: type })
    { op_id: op_id, status: "deferred", retryable: true, code: "server_busy", message: "internal error" }
  end

  # There is no device-side PIN session over the API (API-SPEC.md §1) —
  # every operation carries its own acting_user_id, validated against the
  # shop's active users by the same resolver the offline PWA cold-start
  # path already uses (Sync::ActingUser, used by Sync::OfflineInvoiceIngest).
  def resolve_acting_user(operation, payload)
    Sync::ActingUser.resolve!(shop: Current.shop, current_user: nil, payload: payload.merge("acting_user_id" => operation[:acting_user_id]))
  end

  def translate(op_id, outcome)
    case outcome[:status]
    when "applied"
      { op_id: op_id, status: "accepted" }
    when "duplicate"
      { op_id: op_id, status: "duplicate" }
    when "rejected"
      { op_id: op_id, status: "rejected", retryable: false, code: "validation_failed", message: outcome[:error] }
    else
      { op_id: op_id, status: "deferred", retryable: true, code: "server_busy", message: outcome[:error] }
    end
  end

  def parse_device_time
    value = params[:device_time]
    value.present? ? Time.iso8601(value) : nil
  rescue ArgumentError
    nil
  end

  def operations_params
    params.require(:operations).map do |operation|
      operation.permit(:op_id, :type, :acting_user_id, :occurred_at, payload: {})
    end
  end
end
