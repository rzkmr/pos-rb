require "test_helper"

class PrintingTest < ActiveSupport::TestCase
  setup { Current.shop = shops(:alpha) }
  teardown { Current.reset }

  test "enqueue_invoice! creates a queued invoice print job" do
    invoice = build_invoice

    print_job = Printing.enqueue_invoice!(invoice)

    assert_equal "invoice", print_job.kind
    assert_equal "queued", print_job.status
  end

  test "reprint! creates a duplicate print job, bumps print_count, and writes an audit_event" do
    invoice = build_invoice
    user = users(:alpha_waiter)

    assert_difference [ "PrintJob.count", "AuditEvent.count" ], 1 do
      Printing.reprint!(invoice: invoice, user: user)
    end

    assert_equal 1, invoice.reload.print_count
    assert_equal "duplicate", invoice.print_jobs.order(:created_at).last.kind
  end

  private

  def build_invoice
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    Billing.issue_invoice!(table_session: session)
  end
end
