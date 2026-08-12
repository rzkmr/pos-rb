class TableSessionsController < ApplicationController
  def create
    dining_table = Current.shop.dining_tables.find(params[:dining_table_id])
    session = dining_table.open_session || dining_table.table_sessions.create!(
      opened_by: Current.user,
      opened_at: Time.current,
      status: "open"
    )

    redirect_to table_session_path(session)
  end

  def show
    @table_session = Current.shop.table_sessions.find(params[:id])
    @dining_table = @table_session.dining_table
    @menu_items = Current.shop.menu_items.active.ordered
    @tickets = @table_session.tickets.order(:number).includes(:ticket_items)
  end
end
