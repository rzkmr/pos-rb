class TicketItemsController < ApplicationController
  def void
    ticket_item = TicketItem.joins(:ticket).where(tickets: { shop_id: Current.shop.id }).find(params[:id])
    reason = params.require(:reason)

    ticket_item.void!(reason: reason, by: Current.user)
    AuditEvent.record!(
      action: "void_ticket_item",
      subject: ticket_item,
      user: Current.user,
      device: Current.device,
      payload: { reason: reason, ticket_id: ticket_item.ticket_id }
    )

    redirect_to table_session_bill_path(ticket_item.ticket.table_session)
  end
end
