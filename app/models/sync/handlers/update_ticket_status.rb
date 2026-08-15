module Sync
  module Handlers
    # A replayed status update must never move a ticket BACKWARDS — a
    # stale "preparing" arriving after the kitchen already marked "ready"
    # must be silently dropped, not applied. Rejecting it outright (rather
    # than dropping it) surfaces the mismatch to the client instead of
    # papering over it.
    class UpdateTicketStatus
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @payload = payload
      end

      def call
        ticket = @shop.tickets.find(@payload.fetch("ticket_id"))
        new_status = @payload.fetch("status")

        current_index = Ticket::STATUSES.index(ticket.status)
        new_index = Ticket::STATUSES.index(new_status)
        raise Sync::Handlers::Rejected, "unknown status: #{new_status}" if new_index.nil?

        if new_index > current_index
          ticket.update!(status: new_status)
        elsif new_index < current_index
          raise Sync::Handlers::Rejected, "stale transition: #{ticket.status} -> #{new_status}"
        end

        { ticket_id: ticket.id, status: ticket.status }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
