class KitchenTicketsController < ApplicationController
  def index
    @tickets = Current.shop.tickets
      .where.not(status: "served")
      .order(:placed_at)
      .includes(:ticket_items, :table_session)
  end

  def update
    ticket = Current.shop.tickets.find(params[:id])
    ticket.update!(status: params.require(:status))
    redirect_to kitchen_tickets_path
  end
end
