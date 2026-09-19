# Parks/restores/discards a takeaway cart before it's ever submitted as a
# ticket (design_system §8 "Hold" / "Held orders"). See HeldCart — this is
# deliberately not a TableSession/Ticket, so nothing reaches the kitchen or
# reserves an invoice number until the held cart is restored and charged.
class HeldCartsController < ApplicationController
  def index
    dining_table = Current.shop.dining_tables.find(params[:dining_table_id])
    held_carts = dining_table.held_carts.order(:held_at)

    render json: held_carts.map { |cart| serialize(cart) }
  end

  def create
    dining_table = Current.shop.dining_tables.find(params[:dining_table_id])
    held_cart = dining_table.held_carts.create!(
      items: held_cart_items_params,
      held_by: Current.user,
      held_at: Time.current
    )

    render json: serialize(held_cart), status: :created
  end

  def destroy
    held_cart = Current.shop.held_carts.find(params[:id])
    held_cart.destroy!

    head :no_content
  end

  private

  def held_cart_items_params
    params.require(:items).map do |item|
      item.permit(:menu_item_id, :name_snapshot, :unit_price_paisa, :quantity).to_h
    end
  end

  def serialize(held_cart)
    {
      id: held_cart.id,
      items: held_cart.items,
      held_at: held_cart.held_at.iso8601,
      total_paisa: held_cart.total_paisa,
      item_count: held_cart.item_count
    }
  end
end
