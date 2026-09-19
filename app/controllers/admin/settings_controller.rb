class Admin::SettingsController < Admin::BaseController
  def edit
    @shop = Current.shop
  end

  def update
    @shop = Current.shop

    if params[:admin_pin].present? && !valid_pairing_pin?(params[:admin_pin])
      @shop.errors.add(:base, "Device pairing PIN must be exactly 4 digits")
      return render :edit, status: :unprocessable_entity
    end

    pin_changed = params[:admin_pin].present?
    @shop.pairing_pin = params[:admin_pin] if pin_changed

    if @shop.update(shop_params)
      AuditEvent.record!(
        action: "shop_settings_updated", subject: @shop, admin_user: Current.admin,
        payload: shop_params.to_h.merge(pairing_pin_changed: pin_changed)
      )
      redirect_to edit_admin_settings_path, notice: "Settings updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def shop_params
    params.require(:shop).permit(
      :name, :address, :pan, :vat_rate_bp, :service_charge_rate_bp,
      :invoice_footer, :printer_host, :printer_port
    )
  end

  def valid_pairing_pin?(pin)
    pin.to_s.match?(/\A\d{4}\z/)
  end
end
