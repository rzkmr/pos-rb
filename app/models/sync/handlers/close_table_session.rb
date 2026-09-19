module Sync
  module Handlers
    # A session normally closes itself as a side effect of
    # Billing.record_payment_and_settle! reaching full payment. This
    # handler covers the explicit table_session.close operation
    # (API-SPEC.md §5) for a session an admin/cashier closes without a
    # payment (e.g. a comped table) — it must still be paid in full first;
    # closing an underpaid session would let a bill go out the door
    # uncollected with no audit trail.
    class CloseTableSession
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @payload = payload
      end

      def call
        table_session = @shop.table_sessions.find(@payload.fetch("table_session_id"))
        return { table_session_id: table_session.id, status: table_session.status } if table_session.status == "closed"

        billing = Billing.compute(shop: @shop, gross_paisa: table_session.subtotal_paisa)
        if table_session.paid_paisa < billing.gross_paisa
          raise Sync::Handlers::Rejected, "table_session #{table_session.id} is not fully paid"
        end

        table_session.update!(status: "closed", closed_at: Time.current)
        { table_session_id: table_session.id, status: table_session.status }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
