# One-time first-boot wizard. Creates the shop, its admin pairing PIN, and
# the first admin user. Closed off permanently once a shop exists — see
# Authentication#redirect_to_setup_if_needed, the only other place that
# references this controller.
class SetupController < ApplicationController
  skip_before_action :set_current_shop
  skip_before_action :set_current_device
  skip_before_action :set_current_user
  skip_before_action :require_device
  skip_before_action :require_user
  before_action :ensure_not_already_set_up

  def new
    @shop = Shop.new
  end

  def create
    unless valid_pin?(params[:admin_pin]) && valid_pin?(params[:admin_pin_login])
      @shop = Shop.new(shop_params)
      @shop.errors.add(:base, "Both PINs must be exactly 4 digits")
      return render :new, status: :unprocessable_entity
    end

    @shop = Shop.new(shop_params)
    @shop.invoice_prefix = "INV" if @shop.invoice_prefix.blank?
    @shop.invoice_fy = Shop.financial_year_for(Date.current)
    @shop.gst_rate_bp = 500 if @shop.gst_rate_bp.blank?
    @shop.admin_pin = params[:admin_pin]

    device_token = nil
    ActiveRecord::Base.transaction do
      @shop.save!
      @admin = @shop.users.create!(name: params[:admin_name], role: "admin", pin: params[:admin_pin_login])
      _device, device_token = Device.pair!(shop: @shop, label: "First admin device", kind: "admin")
    end

    cookies.signed[Authentication::DEVICE_COOKIE] = {
      value: device_token,
      httponly: true,
      same_site: :lax,
      expires: 10.years
    }
    redirect_to new_session_path, notice: "Shop set up. Sign in as #{@admin.name} to continue."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def ensure_not_already_set_up
    redirect_to root_path if Shop.exists?
  end

  def shop_params
    params.permit(:name, :gstin, :address, :state_code, :fssai_licence, :invoice_prefix, :gst_rate_bp, :composition_scheme)
  end

  def valid_pin?(pin)
    pin.to_s.match?(/\A\d{4}\z/)
  end
end
