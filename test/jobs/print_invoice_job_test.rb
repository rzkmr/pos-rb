require "test_helper"

class PrintInvoiceJobTest < ActiveJob::TestCase
  test "perform writes ESC/POS bytes to the printer socket and marks the job sent" do
    invoice = build_invoice
    invoice.shop.update!(printer_host: "127.0.0.1", printer_port: 9100)
    print_job = invoice.print_jobs.last

    fake_socket = Minitest::Mock.new
    fake_socket.expect(:write, nil) { |bytes| bytes.is_a?(String) }
    fake_socket.expect(:close, nil)

    Socket.stub(:tcp, fake_socket) do
      PrintInvoiceJob.new.perform(print_job)
    end

    fake_socket.verify
    assert_equal "sent", print_job.reload.status
    assert_equal 1, print_job.attempts
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
