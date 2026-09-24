module Sync
  module Handlers
    # Records that a device already printed an invoice locally (Bluetooth
    # ESC/POS on the Android terminal, or any other client-local printer) —
    # distinct from Printing.reprint!/PrintInvoiceJob, which are the web
    # admin's own path for printing via a network-attached printer
    # (Socket.tcp to shop.printer_host/printer_port). A device that already
    # produced a physical receipt itself must never also enqueue a
    # PrintInvoiceJob here; this handler only updates the audit trail
    # (print_count, an AuditEvent) so print history/print_count stays
    # accurate across every terminal, not just the ones printing through
    # the server.
    class RecordDevicePrint
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @device = device
        @user = user
        @payload = payload
      end

      def call
        invoice = @shop.invoices.find(@payload.fetch("invoice_id"))
        invoice.increment!(:print_count)
        AuditEvent.record!(
          action: "device_print_invoice",
          subject: invoice,
          user: @user,
          device: @device,
          payload: { invoice_number: invoice.number, print_count: invoice.print_count }
        )

        { invoice_id: invoice.id, print_count: invoice.print_count }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
