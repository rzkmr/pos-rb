module Sync
  module Handlers
    # Mirrors TableSessionsController#create's find-or-create — opening a
    # table that's already open is not an error, it's the normal case of a
    # second waiter reaching the same table (API-SPEC.md §7: "Multiple
    # devices add tickets to one session. Allowed."). Only genuinely
    # conflicting opens (two DIFFERENT sessions racing to open the SAME
    # table) need the session_exists rejection path; find-or-create here
    # already prevents that at the DB level rather than detecting it after
    # the fact.
    #
    # `table_sessions.id` is a server-assigned integer; the client's own
    # payload `id` is never adopted as the row's id (it can't be — wrong
    # type, and a client can't be trusted to hand out unique server keys
    # anyway). Instead the payload's `client_token` is the idempotency key
    # (TableSession.resolve_or_open!, the same client_token/id split
    # ticket.create already uses via Ticket.submit!) and this handler's
    # `result` hands back the real `table_session_id` the client must use
    # for every dependent op in the same order (invoice.issue,
    # payment.record, ticket.create, ...). A client that used its own
    # payload id instead would get "Couldn't find TableSession" on every
    # single one of those — not a race, a guaranteed mismatch every time.
    class OpenTableSession
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @user = user
        @payload = payload
      end

      def call
        dining_table = @shop.dining_tables.find(@payload.fetch("dining_table_id"))
        table_session = TableSession.resolve_or_open!(
          shop: @shop,
          dining_table: dining_table,
          client_session_token: @payload.fetch("client_token"),
          opened_by: @user
        )

        { table_session_id: table_session.id, status: table_session.status }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
