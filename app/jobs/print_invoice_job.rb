# Opens a raw TCP socket to the thermal printer and writes ESC/POS bytes.
# See ARCHITECTURE.md §7 — retry with backoff, failure surfaces on the
# cashier screen via PrintJob#status, never silent.
class PrintInvoiceJob < ApplicationJob
  queue_as :default

  CONNECT_TIMEOUT = 5

  retry_on Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError, IOError,
    wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.update!(status: "failed", last_error: error.message)
  end

  def perform(print_job)
    shop = print_job.shop
    invoice = print_job.invoice
    bytes = EscposReceipt.build(invoice: invoice, duplicate: print_job.kind == "duplicate")

    print_job.increment!(:attempts)

    socket = Socket.tcp(shop.printer_host, shop.printer_port, connect_timeout: CONNECT_TIMEOUT)
    begin
      socket.write(bytes)
    ensure
      socket.close
    end

    print_job.update!(status: "sent", sent_at: Time.current, last_error: nil)
  end
end
