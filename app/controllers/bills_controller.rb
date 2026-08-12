class BillsController < ApplicationController
  def show
    @table_session = Current.shop.table_sessions.find(params[:table_session_id])
    @billing = Billing.compute(shop: Current.shop, taxable_paise: @table_session.subtotal_paise)
    @invoice = @table_session.invoices.order(:sequence).last
  end
end
