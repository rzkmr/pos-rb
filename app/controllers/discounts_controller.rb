class DiscountsController < ApplicationController
  def create
    table_session = Current.shop.table_sessions.find(params[:table_session_id])
    amount_paise = params.require(:amount_paise)
    reason = params.require(:reason)

    table_session.apply_discount!(amount_paise: amount_paise, reason: reason, approved_by: Current.user)
    AuditEvent.record!(
      action: "apply_discount",
      subject: table_session,
      user: Current.user,
      device: Current.device,
      payload: { amount_paise: amount_paise, reason: reason }
    )

    redirect_to table_session_bill_path(table_session)
  end
end
