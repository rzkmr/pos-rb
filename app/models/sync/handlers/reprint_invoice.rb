module Sync
  module Handlers
    # Printing.reprint! itself has no idempotency — the outer client_actions
    # ledger in Sync::Replay is what stops a replayed client_action_id from
    # enqueuing a second print job and bumping print_count twice. This
    # handler only needs to be correct once.
    class ReprintInvoice
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @device = device
        @user = user
        @payload = payload
      end

      def call
        invoice = @shop.invoices.find(@payload.fetch("invoice_id"))
        Printing.reprint!(invoice: invoice, user: @user, device: @device)

        { invoice_id: invoice.id, print_count: invoice.reload.print_count }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
