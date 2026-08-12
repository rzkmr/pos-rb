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
      redirect_to admin_menu_items_path, notice: "Menu item added"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @menu_item.update(menu_item_params)
      redirect_to admin_menu_items_path, notice: "Menu item updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.update!(active: false)
    redirect_to admin_menu_items_path, notice: "Menu item deactivated"
  end

  private

  def set_menu_item
    @menu_item = Current.shop.menu_items.find(params[:id])
  end

  def menu_item_params
    params.require(:menu_item).permit(:name, :category, :price_paise, :hsn_sac, :active, :position)
  end
end
