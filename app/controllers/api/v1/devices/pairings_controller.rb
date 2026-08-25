# Pairs a device over the API — the token-authenticated equivalent of the
# web DevicesController#create flow (API-SPEC.md §1: "Admin pairs a
# device once ... the server issues a long-lived opaque token"). Same
# shop pairing PIN and the same shop-wide PairingAttempt lockout backstop
# as the web flow; see DevicesController for why both the per-IP
# rate_limit and the lockout exist.
#
# Deliberately does NOT inherit Api::V1::BaseController: pairing is how a
# device gets its first token, so it cannot require one.
class Api::V1::Devices::PairingsController < ActionController::API
  rate_limit to: 5, within: 15.minutes, by: -> { request.remote_ip },
             with: -> { render json: { error: "too_many_attempts" }, status: :too_many_requests }

  before_action :set_shop
  before_action :require_not_locked_out

  def create
    label = params[:label].to_s.strip.presence || default_device_label

    unless @shop.authenticate_pairing_pin(params[:pairing_pin])
      record_pairing_attempt!(success: false)
      return render json: { error: "invalid_pairing_pin" }, status: :unauthorized
    end

    record_pairing_attempt!(success: true)
    device, token = Device.pair!(shop: @shop, label: label)
    render json: { device: { id: device.id, label: device.label }, token: token }, status: :created
  end

  private

  def set_shop
    @shop = Shop.order(:id).first
    render json: { error: "no_shop_configured" }, status: :unprocessable_entity unless @shop
  end

  def require_not_locked_out
    return unless @shop && PairingAttempt.locked_out?(shop: @shop)

    render json: { error: "pairing_locked" }, status: :too_many_requests
  end

  def record_pairing_attempt!(success:)
    @shop.pairing_attempts.create!(success: success, ip_address: request.remote_ip)
  end

  def default_device_label
    "Device paired #{Time.current.strftime('%-d %b, %-I:%M%p')}"
  end
end
