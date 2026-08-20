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
  before_action :set_current_shop
  before_action :authenticate_device!
  around_action :with_locale

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def with_locale(&block)
    I18n.with_locale(I18n.default_locale, &block)
  end

  def set_current_shop
    Current.shop = Shop.order(:id).first
  end

  def authenticate_device!
    return render_unauthorized("no shop configured") unless Current.shop

    token = bearer_token
    return render_unauthorized("missing bearer token") unless token

    device = Current.shop.devices.find { |d| d.authenticate_token(token) }
    return render_unauthorized("invalid or revoked device token") unless device

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
