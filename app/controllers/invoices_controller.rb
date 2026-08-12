class InvoicesController < ApplicationController
  def reprint
    invoice = Current.shop.invoices.find(params[:id])
    Printing.reprint!(invoice: invoice, user: Current.user, device: Current.device)

    redirect_to table_session_bill_path(invoice.table_session)
  end
end
