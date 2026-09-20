# Base for the token-authenticated API consumed by an external client
# (see API-SPEC.md) — deliberately separate from ApplicationController's
# Authentication concern, which is cookie/session-based for the in-browser
# PWA (Authentication#set_current_device, #set_current_user). An API
# client authenticates every request with `Authorization: Bearer
# <device_token>`; there is no server-side user session — acting_user_id
# travels in each operation's payload instead (API-SPEC.md §1) and is
# resolved per-call via Sync::ActingUser, the same resolver the offline
# PWA cold-start path already uses.
class Api::V1::BaseController < ActionController::API
  before_action :authenticate_device!
  around_action :with_locale

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def with_locale(&block)
    I18n.with_locale(I18n.default_locale, &block)
  end

  # The device token is the only tenant identity the API trusts — there is
  # no shop_id in the request to spoof, and none is needed: a device
  # belongs to exactly one shop (ShopScoped), so authenticating the device
  # IS resolving the shop. Iterates every device rather than scoping the
  # query to a shop first, because which shop it's in is exactly what
  # authenticating this token tells us — see ARCHITECTURE.md §11 for the
  # multi-shop routing this keeps correct ahead of time.
  #
  # ponytail: O(n) bcrypt compares across all devices in the deployment.
  # Fine at single-shop scale (a handful of devices); if this becomes a
  # multi-shop routing hot path, index by a public device_uid looked up
  # first, then bcrypt-verify only that one row.
  def authenticate_device!
    token = bearer_token
    return render_unauthorized("missing bearer token") unless token

    device = Device.unscoped.find { |d| d.authenticate_token(token) }
    return render_unauthorized("invalid or revoked device token") unless device

    Current.shop = device.shop
    Current.device = device
    device.touch_last_seen!
  end

  def bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip.presence
  end

  def render_unauthorized(message)
    render json: { error: message }, status: :unauthorized
  end

  def render_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end
end
