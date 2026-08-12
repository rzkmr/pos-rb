# Queues invoice print jobs. Printing is always a job, never inline in a
# request — see CLAUDE.md. Reprints are marked DUPLICATE and bump print_count.
class Printing
  def self.enqueue_invoice!(invoice)
    print_job = invoice.print_jobs.create!(shop: invoice.shop, kind: "invoice", status: "queued")
    PrintInvoiceJob.perform_later(print_job)
    print_job
  end

  def self.reprint!(invoice:, user:, device: nil)
    print_job = invoice.print_jobs.create!(shop: invoice.shop, kind: "duplicate", status: "queued")
    invoice.increment!(:print_count)
    AuditEvent.record!(
      action: "reprint_invoice",
      subject: invoice,
      user: user,
      device: device,
      payload: { invoice_number: invoice.number, print_count: invoice.print_count }
    )
    PrintInvoiceJob.perform_later(print_job)
    print_job
  end
end
