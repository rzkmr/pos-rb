class PaymentsController < ApplicationController
  def create
    table_session = Current.shop.table_sessions.find(params[:table_session_id])

    ActiveRecord::Base.transaction do
      table_session.payments.create!(
        shop: Current.shop,
        method: payment_params[:method],
        amount_paise: payment_params[:amount_paise],
        reference: payment_params[:reference],
        received_by: Current.user
      )

      settle!(table_session) if fully_paid?(table_session)
    end

    redirect_to table_session_bill_path(table_session)
  end

  private

  def payment_params
    params.require(:payment).permit(:method, :amount_paise, :reference)
  end

  def fully_paid?(table_session)
    billing = Billing.compute(shop: Current.shop, taxable_paise: table_session.subtotal_paise)
    table_session.paid_paise >= billing.total_paise
  end

  def settle!(table_session)
    Billing.issue_invoice!(table_session: table_session) if table_session.invoices.none?
    table_session.update!(status: "paid", closed_at: Time.current)
  end
end
