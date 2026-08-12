# One-time first-boot wizard. Creates the shop, its device pairing PIN,
# and the first admin (web login, username + password). Closed off
# permanently once a shop exists — see
# Authentication#redirect_to_setup_if_needed, the only other place that
# references this controller.
class SetupController < ApplicationController
  skip_before_action :set_current_shop
  skip_before_action :set_current_admin
  skip_before_action :set_current_device
  skip_before_action :set_current_user
  skip_before_action :require_device
  skip_before_action :require_user
  before_action :ensure_not_already_set_up

  def new
    @shop = Shop.new
  end

  def create
    unless valid_pairing_pin?(params[:admin_pin])
      @shop = Shop.new(shop_params)
      @shop.errors.add(:base, "Device pairing PIN must be exactly 4 digits")
      return render :new, status: :unprocessable_entity
    end

    @shop = Shop.new(shop_params)
    @shop.invoice_prefix = "INV" if @shop.invoice_prefix.blank?
    @shop.invoice_fy = Shop.financial_year_for(Date.current)
    @shop.gst_rate_bp = 500 if @shop.gst_rate_bp.blank?
    @shop.admin_pin = params[:admin_pin]

    ActiveRecord::Base.transaction do
      @shop.save!
      @admin_user = @shop.admin_users.create!(username: params[:admin_username], password: params[:admin_password])
    end

    redirect_to new_admin_session_path, notice: "Shop set up. Sign in as #{@admin_user.username} to continue."
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

  def valid_pairing_pin?(pin)
    pin.to_s.match?(/\A\d{4}\z/)
  end
end
