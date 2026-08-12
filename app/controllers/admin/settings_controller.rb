class Admin::SettingsController < Admin::BaseController
  def edit
    @shop = Current.shop
  end

  def update
    @shop = Current.shop
    if @shop.update(shop_params)
      redirect_to edit_admin_settings_path, notice: "Settings updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def shop_params
    params.require(:shop).permit(
      :name, :address, :gstin, :state_code, :fssai_licence,
      :prices_include_tax, :composition_scheme, :invoice_footer,
      :printer_host, :printer_port
    )
  end
end
