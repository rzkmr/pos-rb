require "test_helper"

class DailySalesTest < ActiveSupport::TestCase
  test "aggregates invoice and payment totals for the given day, split by method" do
    shop = shops(:alpha)
    session = table_sessions(:alpha_t1_open)
    Ticket.submit!(
      table_session: session,
      client_token: SecureRandom.uuid,
      placed_by: users(:alpha_waiter),
      items_attributes: [ { menu_item_id: menu_items(:alpha_dosa).id, quantity: 1 } ]
    )
    invoice = Billing.issue_invoice!(table_session: session)
    session.payments.create!(method: "cash", amount_paisa: 100, received_by: users(:alpha_waiter))
    session.payments.create!(method: "card", amount_paisa: invoice.gross_paisa - 100, received_by: users(:alpha_waiter))

    daily_sales = DailySales.new(shop: shop, date: Date.current)

    assert_equal invoice.gross_paisa, daily_sales.invoice_total_paisa
    assert_equal invoice.gross_paisa, daily_sales.payment_total_paisa
    cash_row = daily_sales.by_payment_method.find { |row| row.method == "cash" }
    assert_equal 100, cash_row.total_paisa
  end
end
