class DevicesController < ApplicationController
  skip_before_action :require_device, only: [ :pair, :create ]
  skip_before_action :require_user, only: [ :pair, :create ]
  before_action :require_admin_web_login, only: [ :index, :destroy ]

  rate_limit to: 5, within: 1.minute, by: -> { request.remote_ip },
             with: -> { render plain: "Too many attempts, try again shortly", status: :too_many_requests },
             only: :create

  # Unauthenticated pairing screen: a fresh, unpaired device enters the
  # shop's admin pairing PIN to bind itself. See CLAUDE.md/ARCHITECTURE.md §8.
  def pair
  end

  def create
    unless Current.shop&.authenticate_admin_pin(params[:admin_pin])
      flash.now[:alert] = "Incorrect pairing PIN"
      return render :pair, status: :unprocessable_entity
    end

    device, token = Device.pair!(shop: Current.shop, label: params[:label], kind: params[:kind])
    cookies.signed[Authentication::DEVICE_COOKIE] = {
      value: token,
      httponly: true,
      same_site: :lax,
      expires: 10.years
    }
    redirect_to new_session_path, notice: "Device paired as #{device.label}"
  end

  def index
    @devices = Current.shop.devices.order(:label)
  end

  def destroy
    device = Current.shop.devices.find(params[:id])
    AuditEvent.record!(action: "device_revoked", subject: device, admin_user: Current.admin, device: device)
    device.destroy!
    redirect_to devices_path, notice: "Device revoked"
  end

  private

  # index/destroy manage devices shop-wide — this is an admin (web login)
  # action, independent of whether this particular browser has a device paired.
  def require_admin_web_login
    return if Current.admin

    redirect_to new_admin_session_path
  end
end
