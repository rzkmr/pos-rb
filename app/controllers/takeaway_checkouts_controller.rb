# One tap at a takeaway counter: submit the cart as a ticket (which fires
# to the kitchen immediately via Ticket's broadcasts_refreshes_to), pay the
# exact total in full, issue the invoice, and queue the print job — all in
# one request. See PaymentsController for the itemized/split-payment path
# used when this fast path doesn't fit (partial payment, wrong total, etc).
class TakeawayCheckoutsController < ApplicationController
  def create
    table_session = Current.shop.table_sessions.find(params[:table_session_id])
    items_attributes = ticket_items_params.map do |item|
      { menu_item_id: item[:menu_item_id], quantity: item[:quantity], notes: item[:notes] }
    end

    ActiveRecord::Base.transaction do
      Ticket.submit!(
        table_session: table_session,
        client_token: params.require(:client_token),
        placed_by: Current.user,
        items_attributes: items_attributes
      )

      if table_session.reload.status == "open"
        billing = Billing.compute(shop: Current.shop, gross_paisa: table_session.subtotal_paisa)
        Billing.record_payment_and_settle!(
          table_session: table_session,
          method: params.require(:method),
          amount_paisa: billing.gross_paisa,
          received_by: Current.user
        )
      end
    end

    render json: { table_session_id: table_session.id }, status: :created
  end

  private

  def ticket_items_params
    params.require(:items).map do |item|
      item.permit(:menu_item_id, :quantity, :notes)
    end
  end
end
