module Sync
  module Handlers
    # TicketItem#void! is naturally idempotent on the record (voided_at
    # already set -> no-op update), but the audit_event is not — replaying
    # it would append a second audit row for the same void, corrupting the
    # trail invariant #8 exists to protect. Guard on whether this call is
    # the one that actually caused the transition, not on the record state.
    class VoidTicketItem
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @device = device
        @user = user
        @payload = payload
      end

      def call
        ticket_item = TicketItem.joins(:ticket).where(tickets: { shop_id: @shop.id }).find(@payload.fetch("ticket_item_id"))
        reason = @payload.fetch("reason")

        already_voided = ticket_item.voided_at.present?
        ticket_item.void!(reason: reason, by: @user) unless already_voided

        unless already_voided
          AuditEvent.record!(
            action: "void_ticket_item",
            subject: ticket_item,
            user: @user,
            device: @device,
            payload: { reason: reason, ticket_id: ticket_item.ticket_id }
          )
        end

        { ticket_item_id: ticket_item.id, voided_at: ticket_item.voided_at.iso8601 }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
