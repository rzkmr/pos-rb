class DevicesController < ApplicationController
  skip_before_action :require_device, only: [ :pair, :create, :index, :destroy ]
  skip_before_action :require_user, only: [ :pair, :create, :index, :destroy ]
  before_action :require_admin_web_login, only: [ :index, :destroy ]

  # First line of defense: per-IP throttle. Not sufficient alone against a
  # 4-digit (10,000-combination) PIN — an attacker who rotates source IPs,
  # or shares a NAT gateway with legitimate staff, isn't meaningfully
  # slowed by this. See require_not_locked_out for the shop-wide backstop.
  rate_limit to: 5, within: 15.minutes, by: -> { request.remote_ip },
             with: -> { render plain: "Too many attempts, try again shortly", status: :too_many_requests },
             only: :create
  before_action :require_not_locked_out, only: :create

  # Unauthenticated pairing screen: a fresh, unpaired device enters the
  # shop's admin pairing PIN to bind itself. See CLAUDE.md/ARCHITECTURE.md §8.
  def pair
  end

  def create
    unless Current.shop&.authenticate_pairing_pin(params[:admin_pin])
      record_pairing_attempt!(success: false)
      flash.now[:alert] = "Incorrect pairing PIN"
      return render :pair, status: :unprocessable_entity
    end

    record_pairing_attempt!(success: true)
    device, token = Device.pair!(shop: Current.shop, label: default_device_label)
    cookies.signed[Authentication::DEVICE_COOKIE] = {
      value: token,
      httponly: true,
      same_site: :lax,
      expires: 10.years
    }

    # An admin pairing a device from /admin/devices is confirming setup,
    # not about to use it as a shop-floor tablet — send them back to see
    # it listed rather than dropping them on the staff PIN login screen.
    if Current.admin
      redirect_to devices_path, notice: "Device paired as #{device.label}"
    else
      redirect_to new_session_path, notice: "Device paired as #{device.label}"
    end
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

  # Shop-wide backstop the per-IP rate_limit above can't provide: counts
  # recent failed attempts regardless of which IP made them, so rotating
  # source IPs doesn't help an attacker grind through the PIN's 10,000
  # combinations any faster.
  def require_not_locked_out
    return unless Current.shop && PairingAttempt.locked_out?(shop: Current.shop)

    flash.now[:alert] = "Too many incorrect attempts. Pairing is locked for a few minutes — ask an admin if this keeps happening."
    render :pair, status: :too_many_requests
  end

  def record_pairing_attempt!(success:)
    Current.shop.pairing_attempts.create!(success: success, ip_address: request.remote_ip)
  end

  # Pairing only asks for the PIN — the device isn't labeled by whoever's
  # pairing it. Staff/admin can rename it later from Devices if they want
  # something more specific than a timestamp.
  def default_device_label
    "Device paired #{Time.current.strftime('%-d %b, %-I:%M%p')}"
  end
end
