# Fast counter checkout: build a cart, submit it, take payment, print — all
# on one screen. Backed by an ordinary TableSession against a DiningTable
# flagged takeaway: true, so all existing GST/invoice/payment/print/audit
# code applies unchanged (see ARCHITECTURE.md — takeaway is a UI shape, not
# a new domain concept).
class TakeawayOrdersController < ApplicationController
  def current
    counter = Current.shop.dining_tables.takeaway_counters.first
    return render :no_counter, status: :not_found unless counter

    table_session = counter.open_session || counter.table_sessions.create!(
      opened_by: Current.user,
      opened_at: Time.current,
      status: "open"
    )

    redirect_to takeaway_order_path(table_session)
  end

  def show
    @table_session = Current.shop.table_sessions.find(params[:id])
    @dining_table = @table_session.dining_table
    @menu_items = Current.shop.menu_items.active.ordered
    @tickets = @table_session.tickets.order(:number).includes(:ticket_items)
    @billing = Billing.compute(shop: Current.shop, taxable_paise: @table_session.subtotal_paise)
    @invoice = @table_session.invoices.order(:sequence).last
  end
end
