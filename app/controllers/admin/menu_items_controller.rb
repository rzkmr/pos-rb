class Admin::MenuItemsController < Admin::BaseController
  before_action :set_menu_item, only: [ :edit, :update, :destroy ]

  def index
    @menu_items = Current.shop.menu_items.ordered
  end

  def new
    @menu_item = Current.shop.menu_items.new
  end

  def create
    @menu_item = Current.shop.menu_items.new(menu_item_params)
    if @menu_item.save
      AuditEvent.record!(action: "menu_item_created", subject: @menu_item, admin_user: Current.admin, payload: menu_item_params.to_h)
      redirect_to admin_menu_items_path, notice: "Menu item added"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @menu_item.update(menu_item_params)
      AuditEvent.record!(action: "menu_item_updated", subject: @menu_item, admin_user: Current.admin, payload: menu_item_params.to_h)
      redirect_to admin_menu_items_path, notice: "Menu item updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.update!(active: false)
    AuditEvent.record!(action: "menu_item_deactivated", subject: @menu_item, admin_user: Current.admin)
    redirect_to admin_menu_items_path, notice: "Menu item deactivated"
  end

  private

  def set_menu_item
    @menu_item = Current.shop.menu_items.find(params[:id])
  end

  # The form takes the price in rupees (gross_price_rupees) — staff enter
  # "120" or "120.50", not raw paisa. Converted here, once, at the trust
  # boundary; gross_price_paisa is the only value that ever reaches the
  # model or gets stored (CLAUDE.md invariant #1 — integer paisa, always).
  def menu_item_params
    permitted = params.require(:menu_item).permit(:name, :category, :gross_price_rupees, :active, :position)
    rupees = permitted.delete(:gross_price_rupees)
    permitted[:gross_price_paisa] = (rupees.to_f * 100).round if rupees.present?
    permitted
  end
end
