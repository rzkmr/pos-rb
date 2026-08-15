module Sync
  module Handlers
    # Delegates straight to Ticket.submit!, which is already idempotent on
    # client_token (CLAUDE.md invariant #2) — the ledger wrapper in
    # Sync::Replay is a second, belt-and-suspenders idempotency layer here,
    # since this handler can also be reached by a genuinely new token.
    class SubmitTicket
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @user = user
        @payload = payload
      end

      def call
        table_session = @shop.table_sessions.find(@payload.fetch("table_session_id"))
        items_attributes = @payload.fetch("items").map do |item|
          { menu_item_id: item.fetch("menu_item_id"), quantity: item.fetch("quantity"), notes: item["notes"] }
        end

        ticket = Ticket.submit!(
          table_session: table_session,
          client_token: @payload.fetch("client_token"),
          placed_by: @user,
          items_attributes: items_attributes
        )

        { ticket_id: ticket.id, number: ticket.number }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
