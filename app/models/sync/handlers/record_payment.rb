module Sync
  module Handlers
    # payments has no idempotency of its own beyond the client_token guard
    # Billing.record_payment_and_settle! now enforces — a replayed payment
    # here must not double-credit the session or wrongly settle it twice.
    class RecordPayment
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @user = user
        @payload = payload
      end

      def call
        table_session = TableSession.resolve!(shop: @shop, table_session_id: @payload.fetch("table_session_id"))

        Billing.record_payment_and_settle!(
          table_session: table_session,
          method: @payload.fetch("method"),
          amount_paisa: @payload.fetch("amount_paisa"),
          reference: @payload["reference"],
          received_by: @user,
          client_token: @payload.fetch("client_token")
        )

        { table_session_id: table_session.id, status: table_session.reload.status }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
