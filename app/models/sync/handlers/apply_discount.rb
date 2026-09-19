module Sync
  module Handlers
    # apply_discount! is an absolute update! (not an increment), so it's
    # idempotent on value — but the ledger in Sync::Replay already prevents
    # this handler from running twice for the same client_action_id, so the
    # only remaining case is two DIFFERENT actions setting a discount on
    # the same session (two devices, or a correction). That's a real,
    # legitimate last-writer-wins case, and both must be audited per
    # invariant #8 — never suppressed just because a discount already exists.
    class ApplyDiscount
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @device = device
        @user = user
        @payload = payload
      end

      def call
        table_session = @shop.table_sessions.find(@payload.fetch("table_session_id"))
        amount_paisa = @payload.fetch("amount_paisa")
        reason = @payload.fetch("reason")

        table_session.apply_discount!(amount_paisa: amount_paisa, reason: reason, approved_by: @user)
        AuditEvent.record!(
          action: "apply_discount",
          subject: table_session,
          user: @user,
          device: @device,
          payload: { amount_paisa: amount_paisa, reason: reason }
        )

        { table_session_id: table_session.id, discount_paisa: table_session.discount_paisa }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
