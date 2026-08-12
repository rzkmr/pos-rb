class TicketsController < ApplicationController
  def create
    table_session = Current.shop.table_sessions.find(params[:table_session_id])
    items_attributes = ticket_items_params.map do |item|
      { menu_item_id: item[:menu_item_id], quantity: item[:quantity], notes: item[:notes] }
    end

    ticket = Ticket.submit!(
      table_session: table_session,
      client_token: params.require(:client_token),
      placed_by: Current.user,
      items_attributes: items_attributes
    )

    render json: { id: ticket.id, number: ticket.number, client_token: ticket.client_token }, status: :created
  end

  private

  def ticket_items_params
    params.require(:items).map do |item|
      item.permit(:menu_item_id, :quantity, :notes)
    end
  end
end
