class PaymentsController < ApplicationController
  def create
    table_session = Current.shop.table_sessions.find(params[:table_session_id])

    Billing.record_payment_and_settle!(
      table_session: table_session,
      method: payment_params[:method],
      amount_paisa: payment_params[:amount_paisa],
      reference: payment_params[:reference],
      received_by: Current.user
    )

    redirect_to table_session_bill_path(table_session)
  end

  private

  def payment_params
    params.require(:payment).permit(:method, :amount_paisa, :reference)
  end
end
