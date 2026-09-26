module Sync
  module Handlers
    # Records this invoice's final print status once a device's cashier
    # moves on to the next customer — whether or not a physical print
    # actually happened. Distinct from Printing.reprint!/PrintInvoiceJob,
    # which are the web admin's own path for printing via a network-
    # attached printer (Socket.tcp to shop.printer_host/printer_port); a
    # device that already produced (or attempted and failed to produce)
    # its own physical receipt must never also enqueue a PrintInvoiceJob
    # here.
    #
    # `printed` (defaults true for older clients that predate this field)
    # distinguishes an actual Bluetooth ESC/POS print, which bumps
    # print_count and audits it same as before, from a close-out with no
    # printer/a failed print — that case still writes an audit event (so
    # "this invoice was never printed" is visible in the trail, not just
    # silently absent) but leaves print_count untouched.
    class RecordDevicePrint
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @device = device
        @user = user
        @payload = payload
      end

      def call
        invoice = @shop.invoices.find(@payload.fetch("invoice_id"))
        printed = @payload.fetch("printed", true)
        invoice.increment!(:print_count) if printed

        AuditEvent.record!(
          action: printed ? "device_print_invoice" : "device_closed_invoice_without_printing",
          subject: invoice,
          user: @user,
          device: @device,
          payload: { invoice_number: invoice.number, print_count: invoice.print_count, printed: printed }
        )

        { invoice_id: invoice.id, print_count: invoice.print_count, printed: printed }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
