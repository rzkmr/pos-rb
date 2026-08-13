# One-time first-boot wizard. Creates the shop, its device pairing PIN,
# and the first admin (web login, username + password). Closed off
# permanently once a shop exists — see
# Authentication#redirect_to_setup_if_needed, the only other place that
# references this controller.
class SetupController < ApplicationController
  skip_before_action :set_current_shop, except: [ :done ]
  skip_before_action :set_current_admin, except: [ :done ]
  skip_before_action :set_current_device
  skip_before_action :set_current_user
  skip_before_action :require_device
  skip_before_action :require_user
  before_action :ensure_not_already_set_up, except: [ :done ]

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

    redirect_to done_setup_path(username: @admin_user.username)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  # Offers to pair the browser/device that just finished setup, since it's
  # very often also going to be used as a shop-floor tablet (e.g. the
  # counter). Reachable any time after setup, not just immediately after —
  # it links onward, it doesn't expose anything setup itself didn't.
  def done
    @admin_username = params[:username]
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
